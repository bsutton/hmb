//! Provider-neutral, fail-closed subscriber gateway. No real paid adapters.
use async_trait::async_trait;
use axum::{
    extract::{DefaultBodyLimit, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use rusqlite::{params, Connection, OptionalExtension, TransactionBehavior};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{
    path::Path,
    sync::{Arc, Mutex, MutexGuard},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

pub const MAX_TEXT_BYTES: usize = 16_000;
pub const MAX_OUTPUT_BYTES: usize = 8_000;
// Future text adapter: <=18k total input tokens including framing, <=1k output,
// no images/files/tools/history. At $0.15/$0.60 per million: $0.0033; round up.
pub const RESERVATION_MICRO_USD: i64 = 4_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Error {
    Unauthorized,
    Forbidden,
    Invalid,
    Disabled,
    Quota,
    Rate,
    Busy,
    Budget,
    Conflict,
    Uncertain,
    Storage,
    Provider,
}
impl IntoResponse for Error {
    fn into_response(self) -> Response {
        let (code, message) = match self {
            Self::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized"),
            Self::Forbidden => (StatusCode::FORBIDDEN, "not_entitled"),
            Self::Invalid => (StatusCode::BAD_REQUEST, "invalid_request"),
            Self::Disabled => (StatusCode::SERVICE_UNAVAILABLE, "service_disabled"),
            Self::Quota => (StatusCode::TOO_MANY_REQUESTS, "monthly_allowance_exhausted"),
            Self::Rate => (StatusCode::TOO_MANY_REQUESTS, "rate_limited"),
            Self::Busy => (StatusCode::TOO_MANY_REQUESTS, "concurrency_exhausted"),
            Self::Budget => (StatusCode::SERVICE_UNAVAILABLE, "budget_exhausted"),
            Self::Conflict => (StatusCode::CONFLICT, "idempotency_conflict"),
            Self::Uncertain => (StatusCode::CONFLICT, "outcome_unknown_do_not_retry"),
            Self::Storage => (StatusCode::SERVICE_UNAVAILABLE, "storage_unavailable"),
            Self::Provider => (StatusCode::BAD_GATEWAY, "provider_failed"),
        };
        (code, Json(serde_json::json!({"error":message}))).into_response()
    }
}
impl From<rusqlite::Error> for Error {
    fn from(_: rusqlite::Error) -> Self {
        Self::Storage
    }
}

// Implementations must validate signature, issuer, audience, expiry and revocation.
// Never construct Identity from body/header tenant assertions.
#[derive(Clone)]
pub struct Identity {
    pub tenant: String,
    pub subject: String,
}
pub trait Authenticator: Send + Sync {
    fn authenticate(&self, bearer: &str) -> Result<Identity, Error>;
}
#[derive(Clone)]
pub struct Entitlement {
    pub period_start: i64,
    pub period_end: i64,
    pub monthly_calls: i64,
}
// Implementations verify subscription server-side, membership, refunds and freshness.
// Unknown/stale state must fail closed. Period boundaries must be stable across refreshes.
pub trait Entitlements: Send + Sync {
    fn active(&self, identity: &Identity, now: i64) -> Result<Entitlement, Error>;
}
pub trait Clock: Send + Sync {
    fn now(&self) -> i64;
}
pub struct SystemClock;
impl Clock for SystemClock {
    fn now(&self) -> i64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|v| v.as_secs() as i64)
            .unwrap_or(0)
    }
}
pub struct DenyAll;
impl Authenticator for DenyAll {
    fn authenticate(&self, _: &str) -> Result<Identity, Error> {
        Err(Error::Unauthorized)
    }
}
impl Entitlements for DenyAll {
    fn active(&self, _: &Identity, _: i64) -> Result<Entitlement, Error> {
        Err(Error::Forbidden)
    }
}

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
    pub operation: Operation,
    pub text: String,
}
#[derive(Deserialize, Serialize, Clone, Copy)]
#[serde(rename_all = "snake_case")]
pub enum Operation {
    TextExtract,
}
#[derive(Serialize, Deserialize, Debug)]
pub struct Outcome {
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output: Option<String>,
}
// No Debug on credentials, payload, identity or provider responses.
pub struct ProviderResult {
    pub output: String,
    pub cost_micro_usd: Option<i64>,
}
#[async_trait]
pub trait Provider: Send + Sync {
    // Must be true only after terms, credentials and fixed operation bounds verified.
    fn ready(&self) -> bool;
    // Future implementation must enforce <=18k total input/1k output tokens before
    // sending, bounded wire response and no retry/background work after cancellation.
    async fn extract(&self, text: &str) -> Result<ProviderResult, Error>;
}
pub struct DisabledProvider;
#[async_trait]
impl Provider for DisabledProvider {
    fn ready(&self) -> bool {
        false
    }
    async fn extract(&self, _: &str) -> Result<ProviderResult, Error> {
        Err(Error::Disabled)
    }
}

#[derive(Clone)]
pub struct Limits {
    pub user_burst: i64,
    pub user_refill_seconds: i64,
    pub global_burst: i64,
    pub global_refill_seconds: i64,
    pub user_concurrency: i64,
    pub global_concurrency: i64,
    pub timeout: Duration,
}
impl Default for Limits {
    fn default() -> Self {
        Self {
            user_burst: 20,
            user_refill_seconds: 300,
            global_burst: 100,
            global_refill_seconds: 1,
            user_concurrency: 2,
            global_concurrency: 16,
            timeout: Duration::from_secs(20),
        }
    }
}
#[derive(Clone)]
pub struct Ledger {
    connection: Arc<Mutex<Connection>>,
}
#[derive(PartialEq, Debug)]
enum Reservation {
    New,
    Replay,
}
impl Ledger {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, Error> {
        let connection = Connection::open(path)?;
        connection.busy_timeout(Duration::from_secs(2))?;
        connection.execute_batch(include_str!("schema.sql"))?;
        Ok(Self {
            connection: Arc::new(Mutex::new(connection)),
        })
    }
    // Keep a connection alive: repeatedly opening/closing the last WAL connection
    // races WAL cleanup/recovery and can return SQLITE_BUSY under concurrent load.
    // The process mutex reduces local contention; BEGIN IMMEDIATE remains the
    // cross-connection/process authority for admission and settlement.
    fn connect(&self) -> Result<MutexGuard<'_, Connection>, Error> {
        self.connection.lock().map_err(|_| Error::Storage)
    }
    /// Administrative local hook, never exposed as HTTP. Ceilings are cumulative
    /// ledger lifetime micro-USD, including all unsettled calls, not daily alerts.
    pub fn configure(&self, scope: &str, enabled: bool, ceiling: i64) -> Result<(), Error> {
        if !["global", "text"].contains(&scope) || ceiling < 0 {
            return Err(Error::Invalid);
        }
        self.connect()?.execute(
            "UPDATE switches SET enabled=?2,ceiling=?3 WHERE scope=?1",
            params![scope, enabled, ceiling],
        )?;
        Ok(())
    }
    fn reserve(
        &self,
        id: &Identity,
        key: &str,
        digest: &str,
        e: &Entitlement,
        now: i64,
        l: &Limits,
    ) -> Result<Reservation, Error> {
        let mut c = self.connect()?;
        let tx = c.transaction_with_behavior(TransactionBehavior::Immediate)?;
        for scope in ["global", "text"] {
            let (enabled, ceiling): (bool, i64) = tx.query_row(
                "SELECT enabled,ceiling FROM switches WHERE scope=?1",
                [scope],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )?;
            if !enabled || ceiling == 0 {
                return Err(Error::Disabled);
            }
        }
        // Charge rate capacity even for replay attempts. Separate from call quotas.
        bucket(&tx, "global", now, l.global_burst, l.global_refill_seconds)?;
        let name = serde_json::to_string(&("user", &id.tenant, &id.subject))
            .map_err(|_| Error::Invalid)?;
        bucket(&tx, &name, now, l.user_burst, l.user_refill_seconds)?;
        let existing: Option<(String, String)> = tx
            .query_row(
                "SELECT digest,state FROM requests WHERE tenant=?1 AND subject=?2 AND key=?3",
                params![id.tenant, id.subject, key],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()?;
        if let Some((old, state)) = existing {
            tx.commit()?;
            if old != digest {
                return Err(Error::Conflict);
            }
            return if state == "done" {
                Ok(Reservation::Replay)
            } else {
                Err(Error::Uncertain)
            };
        }
        let count:i64=tx.query_row("SELECT COUNT(*) FROM requests WHERE tenant=?1 AND provider='text' AND created>=?2 AND created<?3",params![id.tenant,e.period_start,e.period_end],|r|r.get(0))?;
        if count >= e.monthly_calls {
            tx.commit()?;
            return Err(Error::Quota);
        }
        let active: i64 = tx.query_row(
            "SELECT COUNT(*) FROM requests WHERE state!='done'",
            [],
            |r| r.get(0),
        )?;
        let user_active: i64 = tx.query_row(
            "SELECT COUNT(*) FROM requests WHERE tenant=?1 AND subject=?2 AND state!='done'",
            params![id.tenant, id.subject],
            |r| r.get(0),
        )?;
        if active >= l.global_concurrency || user_active >= l.user_concurrency {
            tx.commit()?;
            return Err(Error::Busy);
        }
        for scope in ["global", "text"] {
            let ceiling: i64 = tx.query_row(
                "SELECT ceiling FROM switches WHERE scope=?1",
                [scope],
                |r| r.get(0),
            )?;
            let spent: i64 = tx.query_row(
                "SELECT COALESCE(SUM(charged),0) FROM requests WHERE ?1='global' OR provider=?1",
                [scope],
                |r| r.get(0),
            )?;
            if RESERVATION_MICRO_USD > ceiling.saturating_sub(spent) {
                tx.commit()?;
                return Err(Error::Budget);
            }
        }
        tx.execute(
            "INSERT INTO requests VALUES (?1,?2,?3,?4,'text',?5,?6,?6,'pending')",
            params![
                id.tenant,
                id.subject,
                key,
                digest,
                now,
                RESERVATION_MICRO_USD
            ],
        )?;
        tx.commit()?;
        Ok(Reservation::New)
    }
    fn settle(
        &self,
        id: &Identity,
        key: &str,
        actual: Option<i64>,
        valid: bool,
    ) -> Result<(), Error> {
        let mut c = self.connect()?;
        let tx = c.transaction_with_behavior(TransactionBehavior::Immediate)?;
        let reserved:i64=tx.query_row("SELECT reserved FROM requests WHERE tenant=?1 AND subject=?2 AND key=?3 AND state='pending'",params![id.tenant,id.subject,key],|r|r.get(0))?;
        if actual.is_some_and(|n| n < 0 || n > reserved) {
            tx.execute(
                "UPDATE switches SET enabled=0 WHERE scope IN ('global','text')",
                [],
            )?;
            tx.execute("UPDATE requests SET state='unknown',charged=?4 WHERE tenant=?1 AND subject=?2 AND key=?3",params![id.tenant,id.subject,key,actual.unwrap().max(reserved)])?;
            tx.commit()?;
            return Err(Error::Provider);
        }
        // Failed/cancelled calls keep the entire reservation and active slot.
        tx.execute(
            "UPDATE requests SET state=?4,charged=?5 WHERE tenant=?1 AND subject=?2 AND key=?3",
            params![
                id.tenant,
                id.subject,
                key,
                if valid { "done" } else { "unknown" },
                if valid {
                    actual.unwrap_or(reserved)
                } else {
                    reserved
                }
            ],
        )?;
        tx.commit()?;
        Ok(())
    }
    pub fn totals(&self) -> Result<(i64, i64), Error> {
        self.connect()?
            .query_row(
                "SELECT COUNT(*),COALESCE(SUM(charged),0) FROM requests",
                [],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .map_err(Into::into)
    }
}
fn bucket(
    tx: &rusqlite::Transaction<'_>,
    name: &str,
    now: i64,
    capacity: i64,
    interval: i64,
) -> Result<(), Error> {
    if capacity <= 0 || interval <= 0 {
        return Err(Error::Disabled);
    }
    let old: Option<(i64, i64)> = tx
        .query_row(
            "SELECT tokens,updated FROM buckets WHERE name=?1",
            [name],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .optional()?;
    let (tokens, updated) = old.unwrap_or((capacity, now));
    if now < updated {
        return Err(Error::Rate);
    }
    let refill = (now - updated) / interval;
    let available = tokens.saturating_add(refill).min(capacity);
    if available < 1 {
        return Err(Error::Rate);
    }
    let timestamp = if available == capacity {
        now
    } else {
        updated + refill * interval
    };
    tx.execute("INSERT INTO buckets VALUES (?1,?2,?3) ON CONFLICT(name) DO UPDATE SET tokens=excluded.tokens,updated=excluded.updated",params![name,available-1,timestamp])?;
    Ok(())
}

pub struct Gateway {
    pub ledger: Ledger,
    pub auth: Arc<dyn Authenticator>,
    pub entitlements: Arc<dyn Entitlements>,
    pub provider: Arc<dyn Provider>,
    pub clock: Arc<dyn Clock>,
    pub limits: Limits,
}
impl Gateway {
    pub async fn execute(
        &self,
        bearer: &str,
        key: &str,
        request: Request,
    ) -> Result<Outcome, Error> {
        let identity = self.auth.authenticate(bearer)?;
        if identity.tenant.is_empty()
            || identity.subject.is_empty()
            || identity.tenant.len() > 128
            || identity.subject.len() > 128
        {
            return Err(Error::Unauthorized);
        }
        let now = self.clock.now();
        let entitlement = self.entitlements.active(&identity, now)?;
        if now <= 0
            || entitlement.period_start > now
            || entitlement.period_end <= now
            || entitlement.monthly_calls <= 0
        {
            return Err(Error::Forbidden);
        }
        if key.is_empty()
            || key.len() > 128
            || !key
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
            || request.text.is_empty()
            || request.text.len() > MAX_TEXT_BYTES
        {
            return Err(Error::Invalid);
        }
        if !self.provider.ready() {
            return Err(Error::Disabled);
        }
        let encoded = serde_json::to_vec(&request).map_err(|_| Error::Invalid)?;
        let digest = format!("{:x}", Sha256::digest(encoded));
        if self
            .ledger
            .reserve(&identity, key, &digest, &entitlement, now, &self.limits)?
            == Reservation::Replay
        {
            // No response retention. Client must retain its first response.
            return Ok(Outcome {
                status: "already_completed".into(),
                output: None,
            });
        }
        let result =
            tokio::time::timeout(self.limits.timeout, self.provider.extract(&request.text)).await;
        match result {
            Ok(Ok(result)) if result.output.len() <= MAX_OUTPUT_BYTES => {
                self.ledger
                    .settle(&identity, key, result.cost_micro_usd, true)?;
                Ok(Outcome {
                    status: "completed".into(),
                    output: Some(result.output),
                })
            }
            _ => {
                self.ledger.settle(&identity, key, None, false)?;
                Err(Error::Uncertain)
            }
        }
    }
}
pub fn router(gateway: Arc<Gateway>) -> Router {
    let ingress = Arc::new(tokio::sync::Semaphore::new(64));
    Router::new()
        .route("/health", get(|| async { "ok" }))
        .route("/v1/operations", post(operation))
        .layer(DefaultBodyLimit::max(20_000))
        .with_state(gateway)
        .layer(axum::middleware::from_fn(
            move |request: axum::extract::Request, next: axum::middleware::Next| {
                let ingress = ingress.clone();
                async move {
                    let Ok(_permit) = ingress.try_acquire_owned() else {
                        return Error::Busy.into_response();
                    };
                    match tokio::time::timeout(Duration::from_secs(30), next.run(request)).await {
                        Ok(response) => response,
                        Err(_) => Error::Uncertain.into_response(),
                    }
                }
            },
        ))
}
async fn operation(
    State(gateway): State<Arc<Gateway>>,
    headers: HeaderMap,
    Json(request): Json<Request>,
) -> Result<Json<Outcome>, Error> {
    let bearer = headers
        .get("authorization")
        .and_then(|h| h.to_str().ok())
        .and_then(|h| h.strip_prefix("Bearer "))
        .filter(|s| !s.is_empty() && s.len() <= 4096)
        .ok_or(Error::Unauthorized)?;
    let key = headers
        .get("idempotency-key")
        .and_then(|h| h.to_str().ok())
        .ok_or(Error::Invalid)?;
    gateway.execute(bearer, key, request).await.map(Json)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn settlement_is_single_use_and_unknown_never_refunds() {
        let dir = tempfile::tempdir().unwrap();
        let ledger = Ledger::open(dir.path().join("ledger.sqlite")).unwrap();
        ledger.configure("global", true, 10000).unwrap();
        ledger.configure("text", true, 10000).unwrap();
        let id = Identity {
            tenant: "tenant".into(),
            subject: "subject".into(),
        };
        let plan = Entitlement {
            period_start: 1,
            period_end: 1000,
            monthly_calls: 10,
        };
        ledger
            .reserve(&id, "a", "digest", &plan, 100, &Limits::default())
            .unwrap();
        ledger.settle(&id, "a", Some(1000), true).unwrap();
        assert_eq!(ledger.settle(&id, "a", Some(0), true), Err(Error::Storage));
        assert_eq!(ledger.totals().unwrap(), (1, 1000));
        ledger
            .reserve(&id, "b", "digest", &plan, 100, &Limits::default())
            .unwrap();
        ledger.settle(&id, "b", None, false).unwrap();
        assert_eq!(ledger.settle(&id, "b", Some(0), true), Err(Error::Storage));
        assert_eq!(ledger.totals().unwrap(), (2, 5000));
    }
}
