use async_trait::async_trait;
use hmb_subscriber_api::*;
use std::sync::{
    atomic::{AtomicI64, AtomicUsize, Ordering},
    Arc,
};
use std::time::Duration;
use tempfile::TempDir;

struct Auth;
impl Authenticator for Auth {
    fn authenticate(&self, bearer: &str) -> Result<Identity, Error> {
        match bearer {
            "alice" | "bob" => Ok(Identity {
                tenant: bearer.into(),
                subject: bearer.into(),
            }),
            _ => Err(Error::Unauthorized),
        }
    }
}
struct Plan(i64);
impl Entitlements for Plan {
    fn active(&self, _: &Identity, _: i64) -> Result<Entitlement, Error> {
        Ok(Entitlement {
            period_start: 1,
            period_end: 10000,
            monthly_calls: self.0,
        })
    }
}
struct TestClock(AtomicI64);
impl Clock for TestClock {
    fn now(&self) -> i64 {
        self.0.load(Ordering::SeqCst)
    }
}
struct Mock {
    calls: AtomicUsize,
    cost: Option<i64>,
    delay: Duration,
    bytes: usize,
}
#[async_trait]
impl Provider for Mock {
    fn ready(&self) -> bool {
        true
    }
    async fn extract(&self, _: &str) -> Result<ProviderResult, Error> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        tokio::time::sleep(self.delay).await;
        Ok(ProviderResult {
            output: "x".repeat(self.bytes),
            cost_micro_usd: self.cost,
        })
    }
}
fn request() -> Request {
    Request {
        operation: Operation::TextExtract,
        text: "Extract this synthetic customer".into(),
    }
}
struct Fixture {
    _dir: TempDir,
    g: Arc<Gateway>,
    p: Arc<Mock>,
    clock: Arc<TestClock>,
}
fn setup(quota: i64, cost: Option<i64>, delay: Duration, timeout: Duration) -> Fixture {
    let dir = tempfile::tempdir().unwrap();
    let ledger = Ledger::open(dir.path().join("ledger.sqlite")).unwrap();
    ledger.configure("global", true, 1_000_000).unwrap();
    ledger.configure("text", true, 1_000_000).unwrap();
    let p = Arc::new(Mock {
        calls: AtomicUsize::new(0),
        cost,
        delay,
        bytes: 10,
    });
    let clock = Arc::new(TestClock(AtomicI64::new(100)));
    let limits = Limits {
        user_burst: 100,
        global_burst: 100,
        user_concurrency: 100,
        global_concurrency: 100,
        timeout,
        ..Limits::default()
    };
    let g = Arc::new(Gateway {
        ledger,
        auth: Arc::new(Auth),
        entitlements: Arc::new(Plan(quota)),
        provider: p.clone(),
        clock: clock.clone(),
        limits,
    });
    Fixture {
        _dir: dir,
        g,
        p,
        clock,
    }
}
fn standard(quota: i64) -> Fixture {
    setup(
        quota,
        Some(1000),
        Duration::from_millis(2),
        Duration::from_secs(1),
    )
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn atomic_monthly_exhaustion() {
    let f = standard(3);
    let mut joins = vec![];
    for i in 0..24 {
        let g = f.g.clone();
        joins.push(tokio::spawn(async move {
            g.execute("alice", &format!("k{i}"), request()).await
        }));
    }
    let mut successes = 0;
    for j in joins {
        match j.await.unwrap() {
            Ok(_) => successes += 1,
            Err(e) => assert_eq!(e, Error::Quota),
        }
    }
    assert_eq!(successes, 3);
    assert_eq!(f.p.calls.load(Ordering::SeqCst), 3);
    assert_eq!(f.g.ledger.totals().unwrap(), (3, 3000));
}
#[tokio::test]
async fn replay_payload_conflict_and_tenant_isolation() {
    let f = standard(1);
    f.g.execute("alice", "same", request()).await.unwrap();
    assert_eq!(
        f.g.execute("alice", "same", request())
            .await
            .unwrap()
            .status,
        "already_completed"
    );
    let mut changed = request();
    changed.text = "different".into();
    assert_eq!(
        f.g.execute("alice", "same", changed).await.unwrap_err(),
        Error::Conflict
    );
    f.g.execute("bob", "same", request()).await.unwrap();
    assert_eq!(f.p.calls.load(Ordering::SeqCst), 2);
    assert_eq!(
        f.g.execute("alice", "next", request()).await.unwrap_err(),
        Error::Quota
    );
}
#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn concurrent_replay_dispatches_once() {
    let f = standard(20);
    let mut joins = vec![];
    for _ in 0..20 {
        let g = f.g.clone();
        joins.push(tokio::spawn(async move {
            g.execute("alice", "same", request()).await
        }));
    }
    for j in joins {
        if let Err(e) = j.await.unwrap() {
            assert_eq!(e, Error::Uncertain)
        }
    }
    assert_eq!(f.p.calls.load(Ordering::SeqCst), 1);
}
#[tokio::test]
async fn timeout_retains_worst_case_and_survives_restart() {
    let f = setup(
        20,
        Some(1),
        Duration::from_secs(1),
        Duration::from_millis(2),
    );
    assert_eq!(
        f.g.execute("alice", "timed", request()).await.unwrap_err(),
        Error::Uncertain
    );
    assert_eq!(f.g.ledger.totals().unwrap(), (1, 4000));
    let reopened = Ledger::open(f._dir.path().join("ledger.sqlite")).unwrap();
    let g = Gateway {
        ledger: reopened,
        auth: Arc::new(Auth),
        entitlements: Arc::new(Plan(20)),
        provider: f.p.clone(),
        clock: f.clock.clone(),
        limits: Limits::default(),
    };
    assert_eq!(
        g.execute("alice", "timed", request()).await.unwrap_err(),
        Error::Uncertain
    );
    assert_eq!(f.p.calls.load(Ordering::SeqCst), 1);
}
#[tokio::test]
async fn disabled_auth_and_entitlement_fail_before_reserving() {
    let mut f = standard(5);
    assert_eq!(
        f.g.execute("invalid", "a", request()).await.unwrap_err(),
        Error::Unauthorized
    );
    f.g.ledger.configure("text", false, 100000).unwrap();
    assert_eq!(
        f.g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Disabled
    );
    f.g.ledger.configure("text", true, 100000).unwrap();
    Arc::get_mut(&mut f.g).unwrap().entitlements = Arc::new(DenyAll);
    assert_eq!(
        f.g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Forbidden
    );
    assert_eq!(f.g.ledger.totals().unwrap(), (0, 0));
}
#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn budget_reserves_all_in_flight_before_settlement() {
    let f = setup(20, None, Duration::from_millis(50), Duration::from_secs(1));
    f.g.ledger.configure("global", true, 8000).unwrap();
    let mut joins = vec![];
    for i in 0..10 {
        let g = f.g.clone();
        joins.push(tokio::spawn(async move {
            g.execute("alice", &format!("k{i}"), request()).await
        }));
    }
    let mut successes = 0;
    for j in joins {
        match j.await.unwrap() {
            Ok(_) => successes += 1,
            Err(e) => assert_eq!(e, Error::Budget),
        }
    }
    assert_eq!(successes, 2);
    assert_eq!(f.g.ledger.totals().unwrap(), (2, 8000));
}
#[tokio::test]
async fn provider_budget_and_kill_switch() {
    let f = standard(5);
    f.g.ledger.configure("text", true, 3999).unwrap();
    assert_eq!(
        f.g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Budget
    );
    f.g.ledger.configure("text", true, 5000).unwrap();
    f.g.ledger.configure("global", false, 100000).unwrap();
    assert_eq!(
        f.g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Disabled
    );
}
#[tokio::test]
async fn over_bound_cost_trips_both_switches() {
    let f = setup(5, Some(5000), Duration::ZERO, Duration::from_secs(1));
    assert_eq!(
        f.g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Provider
    );
    assert_eq!(f.g.ledger.totals().unwrap(), (1, 5000));
    assert_eq!(
        f.g.execute("bob", "b", request()).await.unwrap_err(),
        Error::Disabled
    );
}
#[tokio::test]
async fn rate_refill_is_independent_of_monthly_allowance() {
    let mut f = standard(3);
    Arc::get_mut(&mut f.g).unwrap().limits.user_burst = 1;
    f.g.execute("alice", "a", request()).await.unwrap();
    assert_eq!(
        f.g.execute("alice", "b", request()).await.unwrap_err(),
        Error::Rate
    );
    f.clock.0.store(400, Ordering::SeqCst);
    f.g.execute("alice", "b", request()).await.unwrap();
    assert_eq!(f.g.ledger.totals().unwrap().0, 2);
}
#[tokio::test]
async fn global_rate_applies_across_tenants() {
    let mut f = standard(5);
    Arc::get_mut(&mut f.g).unwrap().limits.global_burst = 1;
    f.g.execute("alice", "a", request()).await.unwrap();
    assert_eq!(
        f.g.execute("bob", "b", request()).await.unwrap_err(),
        Error::Rate
    );
}
#[tokio::test]
async fn uncertain_work_keeps_concurrency_slot() {
    let mut f = setup(5, None, Duration::from_secs(1), Duration::from_millis(1));
    Arc::get_mut(&mut f.g).unwrap().limits.user_concurrency = 1;
    assert_eq!(
        f.g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Uncertain
    );
    assert_eq!(
        f.g.execute("alice", "b", request()).await.unwrap_err(),
        Error::Busy
    );
    assert_eq!(f.p.calls.load(Ordering::SeqCst), 1);
}
#[tokio::test]
async fn invalid_payload_and_expired_plan() {
    let f = standard(5);
    let mut r = request();
    r.text = "x".repeat(MAX_TEXT_BYTES + 1);
    assert_eq!(
        f.g.execute("alice", "a", r).await.unwrap_err(),
        Error::Invalid
    );
    assert_eq!(
        f.g.execute("alice", "bad/key", request())
            .await
            .unwrap_err(),
        Error::Invalid
    );
    f.clock.0.store(10000, Ordering::SeqCst);
    assert_eq!(
        f.g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Forbidden
    );
    assert_eq!(f.p.calls.load(Ordering::SeqCst), 0);
}
#[tokio::test]
async fn http_rejects_unknown_fields_operations_and_large_bodies() {
    use axum::{
        body::Body,
        http::{Request as HttpRequest, StatusCode},
    };
    use tower::ServiceExt;
    let f = standard(5);
    let app = router(f.g.clone());
    for body in [
        r#"{"operation":"proxy","text":"x"}"#.to_string(),
        r#"{"operation":"text_extract","text":"x","tenant":"bob"}"#.to_string(),
        r#"{"operation":"text_extract","text":"x","model":"expensive"}"#.to_string(),
    ] {
        let response = app
            .clone()
            .oneshot(
                HttpRequest::post("/v1/operations")
                    .header("content-type", "application/json")
                    .header("authorization", "Bearer alice")
                    .header("idempotency-key", "a")
                    .body(Body::from(body))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::UNPROCESSABLE_ENTITY);
    }
    let response = app
        .oneshot(
            HttpRequest::post("/v1/operations")
                .header("content-type", "application/json")
                .body(Body::from("x".repeat(21000)))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::PAYLOAD_TOO_LARGE);
    assert_eq!(f.p.calls.load(Ordering::SeqCst), 0);
}
#[tokio::test]
async fn production_defaults_are_closed() {
    let f = standard(5);
    let ledger = Ledger::open(f._dir.path().join("default.sqlite")).unwrap();
    let g = Gateway {
        ledger,
        auth: Arc::new(Auth),
        entitlements: Arc::new(Plan(5)),
        provider: Arc::new(DisabledProvider),
        clock: f.clock.clone(),
        limits: Limits::default(),
    };
    assert_eq!(
        g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Disabled
    );
    assert_eq!(g.ledger.totals().unwrap(), (0, 0));
}

#[tokio::test]
async fn global_concurrency_includes_other_tenants_and_uncertain_work() {
    let mut f = setup(5, None, Duration::from_secs(1), Duration::from_millis(1));
    Arc::get_mut(&mut f.g).unwrap().limits.global_concurrency = 1;
    assert_eq!(
        f.g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Uncertain
    );
    assert_eq!(
        f.g.execute("bob", "b", request()).await.unwrap_err(),
        Error::Busy
    );
}
#[tokio::test]
async fn oversized_provider_response_retains_reservation() {
    let mut f = standard(5);
    Arc::get_mut(&mut f.g).unwrap().provider = Arc::new(Mock {
        calls: AtomicUsize::new(0),
        cost: Some(1),
        delay: Duration::ZERO,
        bytes: MAX_OUTPUT_BYTES + 1,
    });
    assert_eq!(
        f.g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Uncertain
    );
    assert_eq!(f.g.ledger.totals().unwrap(), (1, 4000));
}
#[tokio::test]
async fn storage_failure_prevents_dispatch() {
    let f = standard(5);
    rusqlite::Connection::open(f._dir.path().join("ledger.sqlite"))
        .unwrap()
        .execute("DROP TABLE requests", [])
        .unwrap();
    assert_eq!(
        f.g.execute("alice", "a", request()).await.unwrap_err(),
        Error::Storage
    );
    assert_eq!(f.p.calls.load(Ordering::SeqCst), 0);
}
#[tokio::test]
async fn http_success_and_credential_redaction() {
    use axum::{
        body::Body,
        http::{Request as HttpRequest, StatusCode},
    };
    use http_body_util::BodyExt;
    use tower::ServiceExt;
    let f = standard(5);
    let app = router(f.g.clone());
    let response = app
        .clone()
        .oneshot(
            HttpRequest::post("/v1/operations")
                .header("content-type", "application/json")
                .header("authorization", "Bearer secret-should-not-appear")
                .header("idempotency-key", "a")
                .body(Body::from(
                    r#"{"operation":"text_extract","text":"customer private text"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let body = response.into_body().collect().await.unwrap().to_bytes();
    assert_eq!(
        std::str::from_utf8(&body).unwrap(),
        r#"{"error":"unauthorized"}"#
    );
    let response = app
        .oneshot(
            HttpRequest::post("/v1/operations")
                .header("content-type", "application/json")
                .header("authorization", "Bearer alice")
                .header("idempotency-key", "a")
                .body(Body::from(
                    r#"{"operation":"text_extract","text":"synthetic"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let result: Outcome = serde_json::from_slice(&body).unwrap();
    assert_eq!(result.status, "completed");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn independent_connections_share_atomic_quota() {
    let f = standard(2);
    let mut gateways = Vec::new();
    for _ in 0..4 {
        gateways.push(Arc::new(Gateway {
            ledger: Ledger::open(f._dir.path().join("ledger.sqlite")).unwrap(),
            auth: Arc::new(Auth),
            entitlements: Arc::new(Plan(2)),
            provider: f.p.clone(),
            clock: f.clock.clone(),
            limits: f.g.limits.clone(),
        }));
    }
    let mut joins = Vec::new();
    for i in 0..16 {
        let g = gateways[i % 4].clone();
        joins.push(tokio::spawn(async move {
            g.execute("alice", &format!("k{i}"), request()).await
        }));
    }
    let mut results = Vec::new();
    for j in joins {
        results.push(j.await.unwrap());
    }
    let successes = results.iter().filter(|r| r.is_ok()).count();
    for error in results.into_iter().filter_map(Result::err) {
        assert_eq!(error, Error::Quota);
    }
    assert_eq!(successes, 2);
    assert_eq!(f.p.calls.load(Ordering::SeqCst), 2);
    assert_eq!(f.g.ledger.totals().unwrap(), (2, 2000));
}

#[tokio::test]
async fn cancelled_caller_keeps_committed_reservation() {
    let f = setup(5, Some(1), Duration::from_secs(30), Duration::from_secs(60));
    let g = f.g.clone();
    let task = tokio::spawn(async move { g.execute("alice", "cancel", request()).await });
    tokio::time::timeout(Duration::from_secs(2), async {
        while f.p.calls.load(Ordering::SeqCst) == 0 {
            tokio::task::yield_now().await;
        }
    })
    .await
    .unwrap();
    task.abort();
    assert!(task.await.unwrap_err().is_cancelled());
    assert_eq!(f.g.ledger.totals().unwrap(), (1, 4000));
    assert_eq!(
        f.g.execute("alice", "cancel", request()).await.unwrap_err(),
        Error::Uncertain
    );
    assert_eq!(f.p.calls.load(Ordering::SeqCst), 1);
}
