use hmb_subscriber_api::{router, DenyAll, DisabledProvider, Gateway, Ledger, Limits, SystemClock};
use std::sync::Arc;
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Local scaffold only: no environment switch can enable authentication or paid calls.
    let ledger = Ledger::open("subscriber-api.sqlite").map_err(|_| "ledger unavailable")?;
    let app = router(Arc::new(Gateway {
        ledger,
        auth: Arc::new(DenyAll),
        entitlements: Arc::new(DenyAll),
        provider: Arc::new(DisabledProvider),
        clock: Arc::new(SystemClock),
        limits: Limits::default(),
    }));
    let listener = tokio::net::TcpListener::bind("127.0.0.1:8787").await?;
    axum::serve(listener, app).await?;
    Ok(())
}
