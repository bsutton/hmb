# Subscriber API foundation — HMB #661

Local Rust scaffold and provider-neutral controls for a fixed-price subscription.
**No real upstream adapter, production authentication or subscription vendor is
configured.** The executable denies all subscriber requests and binds only to
`127.0.0.1:8787`. No setting enables paid calls. It does not change the Flutter app.

```sh
cd server
cargo test --offline
cargo clippy --offline --all-targets -- -D warnings
cargo run --offline
# GET http://127.0.0.1:8787/health returns ok
```

Run in a private directory (production would require owner-only file permissions,
encrypted storage and backups). The local SQLite file and WAL are ignored by Git.
Do not deploy this executable as a production service. See [DESIGN.md](DESIGN.md)
for inventory, source links, economics and remaining decisions.

## Implemented

- `Authenticator` resolves a trusted tenant/subject; `Entitlements` supplies a
  verified subscription period and tenant allowance. Default implementations deny.
- Only `POST /v1/operations` with `operation: "text_extract"` and `text` exists.
  Unknown fields/operations are rejected. No tenant, URL, model or pricing options
  come from the client. Bearer credential and idempotency key are headers.
- 20 KB HTTP body, 16 KB text, 8 KB returned output, 20-second provider deadline,
  30-second HTTP processing deadline, 64 concurrent HTTP handlers. Wire-level
  connection/header deadlines and ingress DDoS protection remain deployment work.
- Durable SQLite `BEGIN IMMEDIATE` serializes rate, monthly quota, outstanding
  concurrency and budget admission across connections using the same database.
  WAL and FULL synchronous mode are used. Database failures prevent dispatch.
- Tenant-wide monthly operation quota; per-subject token bucket and concurrent
  work limits; global bucket and concurrent work limits. Quota-denied and replay
  attempts consume available rate capacity. No public signup or trial-credit path.
- Global and `text` provider switches default off with zero budgets. Budget
  configuration is a local administrative library hook, never an HTTP endpoint.
  Budgets are **cumulative lifetime ceilings** in integer micro-USD, not monthly
  auto-reset budgets. Increasing them needs an explicit administrative decision.
- Every dispatch first commits a 4,000 micro-USD reservation and one allowance
  unit. Settlement releases unused spend once when trusted bounded usage arrives;
  allowance units are not refunded. No automatic retries or background dispatch.
- Idempotency uses tenant + subject + key and SHA-256 of the serialized request.
  Changed content conflicts. Completed replay returns `already_completed` without
  redispatch; output is not retained. Clients must retain the first response.
- Timeout, malformed/oversized result and restart leave a full-cost obligation
  and occupied concurrency slot. Ambiguous requests cannot be replayed. No lease
  expiration pretends that upstream work stopped. Reconciliation is future work.
- A reported cost outside the reserved bound trips both kill switches. Actual
  overshoot is recorded if known, but cannot be undone by the gateway.
- No credentials or request/response content are logged or stored. The ledger
  holds opaque identity, idempotency key, digest, timestamp, state and cost only.
  Digests are pseudonymous metadata, not anonymization; use synthetic data here.

`Provider::ready` is a trusted adapter gate, not a client flag. A future real
adapter must validate credentials/terms, fix model and operation shape, calculate
all input tokens including templates, enforce upstream output-token and response
stream limits, disable automatic SDK retries and reject stale pricing. The current
output check is after a mock response is materialized; it is not a wire-stream
memory limit. There is deliberately no generic HTTP client or paid implementation.

## Tests and limits

Mock-provider tests exercise atomic concurrent quota and budget exhaustion,
concurrent replays, changed payloads, tenant isolation, expiration, rate refill,
global/user concurrency, disabled defaults, settlement once, uncertain recovery,
response size, HTTP schema/body limits, storage failure and error redaction.
No test calls a real paid provider.

This is a single-node SQLite foundation. Synchronous database/auth hooks are
appropriate for the local scaffold, not a production load claim. Production needs
bounded database workers, real async identity/entitlement verification, migrations,
retention/reconciliation, TLS/ingress hardening and multi-instance storage design.
Do not put separate database copies behind a load balancer. Restoring stale usage
state can reopen spent allowance: keep service off after restoration until usage
and outstanding work are reconciled. Never delete records to reset budgets.
