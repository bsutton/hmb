# HMB subscriber integration design

Issue: https://github.com/bsutton/hmb/issues/661

Inventory baseline: `bsutton/hmb` main `51a4d8e6846fedde31955cbdcc9c484ed44b5138`.
Repository and provider documentation reviewed 2026-10-12 UTC. Prices/terms below
are a point-in-time design input, not accepted terms or an approved purchase.

## Existing systems and scope

The HMB repository is Flutter/Dart. Its AGENTS.md requires separate issue work and
sidecar test execution. Existing worktrees include invoice cleanup #659 and the
Bunnings prototype; neither is changed. This issue has its own worktree/branch.
No `.agents` directory or nested server instructions were found in HMB.

`/home/bsutton/git/handyman/ihserver` is the real Dart/Shelf website and booking
backend. `lib/src/router.dart` exposes booking fetch/ack/reject endpoints;
`lib/src/hmb_auth.dart` checks one configured bearer token. HMB consumes it through
`lib/api/ihserver/ihserver_api_client.dart`. That backend lacks subscriber identity,
entitlements, tenant isolation and paid-provider accounting. Its business booking
contracts should be reused when that feature is generalized; its single personal
service token and Brett's bookings must never be offered to subscribers.

No suitable HMB Rust backend was found in the repository or inspected local Rust
projects (batman is file monitoring; reVault is vault infrastructure). This `server`
module is a local foundation within HMB, not a new published service/repository or
a replacement for ihserver. Decide how to host or integrate it before production.

## Integration inventory

| Integration and source | Current access | Subscriber design / commercial status |
| --- | --- | --- |
| Xero: `lib/api/xero/{xero_auth,xero_api,xero_invoice_payment_sync_service}.dart` | Customer OAuth, tenant IDs, invoice/payment/contact operations | Customer authorizes their own organisation. HMB developer app and plan required; never share Brett's grants. Related PKCE issue #394 remains separate. |
| QuickBooks: `lib/api/accounting/quickbooks_{auth,invoice_client,invoice_export}.dart` | Customer OAuth, accounting scope and realm | Validate tenant-to-realm grant ownership on every operation; customer maintains their accounting subscription. Developer programme costs are additional. |
| Drive: `lib/database/management/backup_providers/google_drive/` | Google user authorization; database/photo backups | Customer's own Drive, least privilege; do not place subscribers' backups in Brett's Drive. Large-file bytes and API method units require separate bounds. |
| Calendar: `lib/integrations/google_calendar/google_calendar_sync.dart` | Google user authorization | Customer calendar consent, grant-scoped IDs and disconnect cleanup. Shared application registration is not shared user access. |
| Gmail: `lib/integrations/gmail/`, `lib/ui/dialog/google_mail_auth.dart` | Separate readonly import and mail/SMTP OAuth paths | Restricted scopes; verification/security assessment and Limited Use review. Do not enable custom Gmail. No mailbox data routed through this scaffold. |
| OpenAI: `lib/api/chat_gpt/{receipt,customer_extract,job_assist}_api_client.dart` | API-key calls, `gpt-4o-mini`; image/document and text workflows | Operator-funded API features possible under application terms. No resale/distribution of account or key. Each media workflow needs its own token/cost envelope. |
| `lib/api/chat_gpt/chat_gpt_auth_service.dart` | Placeholder `YOUR_CLIENT_ID`, unverified `chatgpt.extract` scope | Not evidence of supported ChatGPT consumer OAuth/API entitlement. Do not build on it or share a ChatGPT subscription. |
| Maps trip capture: `lib/api/trip_capture_service.dart` | API key, Routes distance/duration | Narrow basic route operation is a candidate for operator funding subject to Maps terms. |
| Maps mailings: `lib/ui/tools/mailings/google_maps_route_service.dart` | Key, geocoding, autocomplete, waypoint optimization, fallback requests | One UI action can trigger many billable requests and higher SKUs. Do not price as one basic route; bound fan-out and reserve each underlying call. |
| ihserver booking sync | Configurable URL + static bearer | Existing business-specific service; separate tenant redesign required. No arbitrary URL proxy in subscriber gateway. |
| SMTP, native email/SMS, device location, external map links | User mailbox/device/provider contracts | Not generic paid API resale. Keep customer authorization. SMTP service plans and sending restrictions need separate review if centralized. |
| Sentry | Application telemetry | Operational cost/retention/privacy rather than customer API allowance; no personal data or credential logging. |

No other charged provider was identified in the source URL/dependency inventory.
This is a code inventory, not an assertion about uninspected account contracts.

## Official terms and cost findings

- [OpenAI Services Agreement](https://openai.com/policies/services-agreement/)
  §2.2 permits API-backed customer applications for end users; §§3.1/3.3 restrict
  account sharing/resale and key transfer. This supports bounded HMB features with
  server-held credentials, not selling access to Brett's account. End-user consent,
  privacy and supported-country obligations still apply.
- [GPT-4o-mini model pricing](https://developers.openai.com/api/docs/models/gpt-4o-mini)
  lists US$0.15/million input and $0.60/million output tokens. Model choice here is
  a modelling example matching current HMB code; no vendor commitment or live call.
- [Maps terms](https://cloud.google.com/maps-platform/terms) allow customer
  applications but restrict reselling services and exporting/storing Maps content.
  Attribution and service-specific rules apply. Review HMB's actual route display,
  stored geocodes and mailing suggestions before enabling shared commercial use.
- [Maps price list](https://developers.google.com/maps/billing-and-pricing/pricing):
  first standard paid tier Routes Essentials/geocoding $5 per 1,000; Routes Pro
  $10 per 1,000; autocomplete requests $2.83 per 1,000. Matrix events are elements,
  not whole HTTP requests. SKU/field-mask/waypoint changes must change reservations.
  Shared monthly free usage is deliberately excluded from per-subscriber modelling.
- [Xero pricing](https://developer.xero.com/pricing): Starter 5 connections free;
  Core AUD35/month up to 50; Plus AUD245 up to 1,000; Advanced AUD1,445 up to 10,000.
  Paid tiers include 10/50/250 GB egress respectively, then AUD2.40/GB; tax excluded.
  [Developer terms](https://developer.xero.com/xero-developer-platform-terms-conditions)
  allow charging for an app, restrict platform/data resale and prohibit AI training
  on API data; third-party data passing requires user consent. An accounting
  subscription or open-source licence alone does not confer redistribution rights.
- [Intuit programme guide](https://static.developer.intuit.com/resources/Intuit_App_Partner_Program_Guide.pdf)
  pp.8–10: Builder has no programme fee and 500,000 shared monthly CorePlus credits,
  with calls above that blocked. Silver is US$300/month, 1m included CorePlus, then
  $3.50/1,000 in the next band; Core calls are uncapped in the listed tiers.
  Costs aggregate at workspace level, not independently per subscriber. Confirm
  actual country rate card, operation classification, app assessment and contracts.
  The legal agreement page did not return readable text in this research run:
  commercial redistribution rights are **not confirmed**, and enablement is blocked.
- [Google User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)
  requires purpose-limited, transparent consent-based access. [Gmail scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)
  classify readonly mail access as restricted; server processing/storage can trigger
  a security assessment. A shared project never authorizes access to another user's
  mailbox, calendar or files.
- Current official [Drive](https://developers.google.com/workspace/drive/api/guides/limits),
  [Calendar](https://developers.google.com/workspace/calendar/api/guides/quota), and
  [Gmail](https://developers.google.com/workspace/gmail/api/reference/quota) pages
  describe standard use at no additional cost and planned excess-use billing later
  in 2026, with details/notice still to come. Published daily project thresholds are
  400m Drive units, 1m Calendar requests and 80m Gmail units. Do not assume permanent
  zero cost or divide project thresholds into unlimited customer grants.

These findings support a feature-based SaaS design, subject to the specific
application's terms and approvals. None constitutes blanket API resale permission.

## Subscription economics and bounded example

At US$30–40/month, a 15% store fee leaves $25.50–34.00 before tax, refunds, support,
hosting and upstream costs. A 30% fee stress case leaves $21–28. The user requires
fixed included allowances and **no per-transaction charges**. Exhaustion blocks
further calls until renewal; a burst changes pacing, never monthly allowance.

The $1–2 upstream target is a model, not a configured budget or approved spend.
Bound operation size first:

| Example operation | Required future adapter bounds | Worst case / proposed allowance |
| --- | --- | --- |
| Text extraction | Fixed `gpt-4o-mini` snapshot after selection; <=16,000 UTF-8 user bytes, <=18,000 total input tokens including templates/schema, <=1,000 output tokens; no history, images, tools, URLs or retry | $0.0033 computed; reserve $0.004/call. 150 calls reserve $0.60. |
| Basic route | One Routes Essentials request, coordinates only, two endpoints, no intermediate stops, traffic/optimization or higher-SKU fields; one dispatch, bounded response | $0.005/call. 80 calls = $0.40. |
| Geocode | One address <=512 bytes, one request, no Places fallback; bounded result count/response | $0.005/call. 40 calls = $0.20. |

Total conservative reservation: **$1.20/subscriber/month**, versus $1.095 at the
listed maximum text token cost and basic Maps rates. No cache/free-tier discounts
are assumed. Remaining $0.80 below the upper target is not authorization for other
operations: it must absorb uncertainty or be explicitly allocated later.

Token accounting must use the selected model's tokenizer on the entire serialized
upstream request. A byte bound alone is not proof of the final token count. Current
image receipts/PDF imports are excluded: pages, image dimensions/detail, OCR and
file processing could make their cost materially different. Reserve a separately
validated media envelope before offering them. This scaffold implements only the
mock text operation; the Maps rows are design examples, not working adapters.

Accounting fixed fees can dominate: Core Xero is AUD3.50/customer with 10 connected
subscribers versus AUD0.70 with 50, before egress/tax and currency conversion.
Intuit Silver is US$30/customer with 10 customers or $3 with 100, even before paid
calls. Builder eligibility/capacity could avoid that fee but must be verified.
Do not promise all integrations within $1–2 based only on token prices.

Example pacing: text bucket of 20 upfront calls, one token replenished each five
minutes, user concurrency 2, global concurrency 16. This helps onboarding but still
cannot exceed the tenant's monthly 150 calls. Maps would have distinct buckets and
allowances. Global limits must be sized to approved spend and infrastructure.

## Architecture and production gates

1. The app authenticates with a selected identity system. Validate issuer,
   signature, audience, expiry and revocation; resolve tenant membership on server.
   No bearer token, plan, store receipt or tenant value is trusted merely because
   the app sends it. Reject unknown/stale entitlement state.
2. A server-side entitlement adapter verifies store purchases/restores, renewal,
   refunds and grace policy. Bind an original transaction to one subscriber/tenant
   atomically to prevent repeated onboarding allowances. No automatic free quota
   on new identities. Choose stable subscription period boundaries before launch.
3. Customer OAuth remains customer-authorized. If server custody is chosen, use
   `(tenant, provider, external organisation, grant)` identifiers, encrypted secret
   storage, PKCE/state/redirect validation, least privilege and revocation/deletion.
   Never fetch an external organisation by a bare client-provided ID. OAuth custody
   is not implemented here; no customer grants or personal data were loaded.
4. Admit only versioned operations. The trusted adapter fixes endpoint, model,
   fields, token limit and maximum fan-out. All retries need new explicit bounded
   reservations unless the upstream guarantees idempotent billing. No automatic
   fallback to expensive models or alternative providers.
5. One atomic transaction checks persisted switches, rate buckets, current period
   calls, unresolved concurrency, provider and global spend including in-flight
   obligations, then records the reservation before dispatch. Reservation is the
   admission linearization point: a later kill switch cannot cancel work already
   admitted, but its worst-case spend is already accounted for.
6. Store only opaque identity and accounting metadata; no content cache. Completed
   replay confirms prior completion without exposing another customer's output.
   Unknown outcomes retain their entire cost and slot across restart. An operator
   must reconcile upstream completion/usage before releasing an unknown slot; that
   administrative workflow is deliberately absent, preventing unsafe auto-release.
7. Provider dashboards lag and cancellation does not guarantee upstream work stops.
   Internal budgets only bound admitted obligations under valid prices and request
   bounds. They do not guarantee the literal invoice total (tax, currency, external
   key use, fees and provider accounting can differ). Use dedicated restricted
   provider credentials/projects and supported provider caps when eventually
   approved, plus an explicit contingency reserve. Never describe alerts as caps.
8. Before production: select database/hosting and migration strategy, private file
   permissions/encryption, async bounded DB workers, TLS and ingress connection/IP
   controls, key rotation and admin audit, price-version validation, durable
   reconciliation and backup-restore safeguards. Multiple gateway replicas must
   share one authoritative transactional ledger, not local copies.
9. Retention needs an approved period and deletion policy. The scaffold retains
   usage/idempotency metadata indefinitely to avoid silently restoring quota on
   purge. Production should keep aggregate obligations and tombstones sufficient
   to prevent replay, expire content independently, and implement tenant deletion
   according to applicable accounting/privacy obligations. No response content is
   retained now; request digests still require protection against dictionary tests.

## Decisions required before a real adapter or deployment

- Identity vendor and solo subscriber versus multi-user business tenant semantics.
- Store/billing verifier, refund/grace rules, period boundaries, one-transaction
  ownership and restore handling. Price/store fee assumptions require confirmation.
- Which integrations are included at launch; exact text/media/Maps operations and
  fixed monthly allowances. Confirm a model snapshot, tokenizer and quality target.
- Operator entity/accounts, provider agreements/app assessments, Google verification
  and Maps display/storage compliance. Intuit terms need readable contract review.
- Explicit provider/global spending ceilings, contingency, concurrency and exposure
  from already admitted work. No default dollars are authorized.
- OAuth on-device versus encrypted server custody; retention/deletion and residency.
- Host/store choice and relationship to existing ihserver. The Rust module must not
  become a competing booking backend by accident.

No deployment, credentials, persistent access expansion, custom Gmail enablement,
real charged requests, repository publication, push/merge/release or terms acceptance
is part of this work. Keep issue #661 in progress until those follow-on acceptance
criteria are addressed; passing scaffold tests is not production readiness.
