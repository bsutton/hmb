# HMB Project Plan

**Repo**: [ZoltyMat/hmb](https://github.com/ZoltyMat/hmb) (forked from bsutton/hmb)
**Date**: 2026-03-27
**Status**: Phase 1 Complete — CI Green — K3s Deployed
**Vision**: Apple-quality trade CRM — multi-user, multi-platform, offline-first, AI-powered

---

## Project Summary

HMB (Hold My Beer) is a Flutter CRM for trade businesses. Forked to transform from a capable-but-rough solo-developer tool into a polished, multi-user, production-grade application with Apple-level UX, self-hosted infrastructure, and optional cloud deployment.

## Goals

1. **Security hardening** — Fix vulnerabilities, harden for public repo
2. **Apple-quality UX overhaul** — Cupertino design system, grouped lists, proper state management
3. **Architecture cleanup** — Fix DAO god classes, add service layer, proper error handling
4. **Multi-AI provider support** — Abstracted AI layer with OpenRouter/Claude/Ollama
5. **Multi-user + sync** — Server-backed auth, offline-first sync engine
6. **Dual hosting** — k3s (primary, self-hosted) + AWS serverless (optional, budget-conscious)
7. **API integration** — OpenClaw, webhooks, extensibility
8. **Feature completion** — Invoicing, quoting, analytics, notifications

---

## Public Repo Security

**DONE** (2026-03-27):
- [x] Branch protection on `main` (PR required, CODEOWNER review, no force push, enforce admins)
- [x] GitHub secret scanning + push protection enabled
- [x] Dependabot vulnerability alerts enabled
- [x] `.github/CODEOWNERS` — `@ZoltyMat` owns all paths
- [x] `.gitignore` hardened (keystores, DBs, env files, google-services)

**Also Done** (2026-03-27):
- [x] Extract hardcoded Sentry DSN to runtime config (PR #2)
- [x] Extract hardcoded Google OAuth client IDs to runtime config (PR #2)
- [x] AES-256-CBC backup encryption before cloud upload (PR #3)
- [x] PKCE added to Xero and ChatGPT OAuth flows (PR #4)
- [x] Dockerfile, nginx config, k8s manifests, CI workflow (PR #5)
- [x] Remove private onepub.dev dependencies (PR #6)
- [x] K3s deployment live at `hmb.k3s.internal.strommen.systems`

**Remaining**:
- [ ] Review upstream license — verify fork and contribution rights
- [ ] Ensure no customer PII in test fixtures

---

## Current State Assessment

### What's Good
- Well-designed entity model (Customer → Job → Task → Quote → Invoice relationships)
- FSM-based job lifecycle (fsm2) — clean state machine with proper events/transitions
- Offline-first SQLite architecture
- Parameterized SQL queries (no injection risk)
- Good time tracking, shopping lists, packing lists
- Xero accounting integration (partial)
- AI integration started (ChatGPT for extraction, receipts, job assist)

### What's Broken (Critical UX Issues Found)

| Issue | Severity | Impact |
|-------|----------|--------|
| **Global June state pollution** | HIGH | Cross-form contamination — editing Job B shows Job A's customer |
| **Toast-only error handling** | HIGH | Users can't tell which field failed; errors auto-dismiss in 6s |
| **FutureBuilderEx race conditions** (91 instances) | HIGH | Unpredictable UI flickering, duplicate DB queries |
| **DAO god classes** (DaoJob: 783 lines, DaoTask: 634 lines) | HIGH | Business logic mixed with data access, no transaction safety |
| **No form dirty-state tracking** | MEDIUM | Back button silently discards unsaved work |
| **No search debouncing** | MEDIUM | Every keystroke fires a DB query |
| **Long scrolling forms with no sections** | MEDIUM | 15+ fields in a single scroll view |
| **No skeleton/loading states** | MEDIUM | Screens blank for 500ms, then flicker |
| **No pagination or virtual scrolling** | MEDIUM | Lists load everything into memory |
| **Three conflicting state management patterns** | MEDIUM | June + Provider + raw setState scattered randomly |
| **No responsive layout** | MEDIUM | Single-column forms unusable on tablets |
| **No pull-to-refresh** | LOW | Mobile UX expectation missing |
| **Empty states confusing** | LOW | Disabled "Add" button with unclear messaging |

### Feature Completeness

| Feature | Status | Usability |
|---------|--------|-----------|
| Core CRM (customers, jobs, contacts) | 90% | Good |
| Time Tracking | 95% | Good |
| Task Management | 90% | Good |
| **Invoicing** | **60%** | **Poor** — broken billing overrides, no invoice FSM, no tax |
| **Quoting** | **70%** | **Fair** — no amendments, no per-line rejection, no versioning |
| Scheduling | 70% | Basic — no drag-drop, no crew, no recurring |
| Dashboard | 60% | OK — dashlets work, zero analytics |
| Search | 40% | Weak — no global search, no advanced filters |
| Reporting/Analytics | **0%** | **Missing entirely** |
| Multi-User | **0%** | **Missing entirely** |
| Server Sync | 10% | Google Drive backup only |
| Notifications | **0%** | **Missing entirely** |
| Customer Portal | **0%** | **Missing entirely** |

---

## Design System: Apple-Inspired

### Philosophy
Borrow Apple's design language: Cupertino widgets, grouped lists, semantic colors, generous whitespace, spring animations. The app should feel like a native iOS productivity app — not a Material Design prototype.

### Core Principles
1. **`CupertinoApp` root** — not MaterialApp. Cupertino navigation, tab bar, controls everywhere
2. **Grouped inset lists** as the primary layout pattern (Settings-style sections with rounded corners)
3. **One tint color** — Blue or Teal for all interactive elements
4. **8pt spacing grid** — all padding/margins in multiples of 4/8
5. **SF Pro typography scale** — Large Title (34pt), Title1-3, Headline, Body, Footnote, Caption
6. **Semantic colors** — label/secondaryLabel/tertiaryLabel, systemBackground/secondarySystemBackground
7. **Light + Dark mode from day one** — all custom colors as light/dark pairs
8. **44pt minimum touch targets** — non-negotiable
9. **Progressive disclosure** — summary on list, details on tap, sections expandable
10. **Spring animations** — 250-350ms, critically damped. Respect Reduce Motion

### Design Token Architecture
```
lib/design_system/
  tokens/       # colors.dart, typography.dart, spacing.dart, radius.dart
  atoms/        # app_icon, app_text, status_badge, avatar
  molecules/    # grouped_list_row, form_field_row, job_card, stat_card
  organisms/    # grouped_list, search_bar, action_sheet
  theme.dart    # ThemeExtension assembly
```

### Key Screen Patterns

**Dashboard**: Card-based grid with greeting hero, stat cards (2x2), today's schedule, activity feed
**Job List**: Grouped list with search, status dots, swipe actions (complete/delete), long-press context menu
**Customer Profile**: Hero header with avatar + quick actions (call/text/email), grouped sections (contact, job history, invoices, notes)
**Invoice**: Document-style presentation — large number, status badge, line items, totals, action buttons
**Settings**: Pure grouped list (iOS Settings clone)
**Forms**: Grouped list rows as fields (label left, input right), section headers, inline validation errors in systemRed

### Recommended Flutter Packages
- `flutter_animate` — Spring animations, staggered sequences
- `shimmer` — Skeleton loading placeholders
- `fl_chart` — Dashboard charts
- `flutter_slidable` — Swipe actions on list items
- `modal_bottom_sheet` — iOS-style sheets with proper physics
- `cached_network_image` — Image loading with placeholders

---

## Architecture

### Current (Upstream)
```
Mobile App (Flutter) → SQLite (local) → Google Drive (backup)
  + Xero (accounting) + ChatGPT (AI) + IHServer (bookings)
```

### Target (Phase 1-5)
```
Flutter (Web/Mobile/Desktop)
  ├── SQLite (local, offline-first source of truth)
  ├── Design System (Cupertino + custom tokens)
  ├── Service Layer (business logic, replaces DAO bloat)
  ├── AIProvider abstraction
  │     ├── OpenRouter (default)
  │     ├── Claude (Anthropic)
  │     ├── Ollama (self-hosted)
  │     └── OpenAI (fallback)
  └── Sync Engine (outbox + pull, offline-first)
        ↕
  HMB API Server (k3s or AWS Lambda)
  ├── Auth (Authentik on k3s / Cognito on AWS)
  ├── PostgreSQL or DynamoDB
  ├── Object Storage (MinIO on k3s / S3 on AWS)
  ├── AI Proxy
  ├── Webhook dispatch
  └── Prometheus /metrics
```

### Dual Hosting Strategy

Every external service has both a self-hosted (k3s) and cloud (AWS) option. **Build self-hosted first**, add AWS as a deployment target.

| Concern | Self-Hosted (k3s) | AWS Serverless | Build Both? |
|---------|-------------------|----------------|-------------|
| **Frontend** | nginx pod + Traefik ingress | CloudFront + S3 | Yes — trivial |
| **API** | Python/Dart pod in k3s | API Gateway + Lambda | Yes — same code, different entry point |
| **Auth** | Authentik (already in cluster) | Cognito (free 50K MAU) | Yes — JWT validation is provider-agnostic |
| **Database** | PostgreSQL 16 StatefulSet | DynamoDB (free tier) | Pick one per env — API abstracts it |
| **Object Storage** | MinIO (k3s pod) | S3 | Yes — S3-compatible API identical |
| **AI Proxy** | LiteLLM on k3s (already deployed) | Lambda → OpenRouter | Yes — same routing logic |
| **Real-time Sync** | WebSocket via Traefik | API Gateway WebSocket | Same protocol |
| **Monitoring** | Prometheus + Grafana (existing) | CloudWatch | k3s primary, CW optional |
| **TLS** | cert-manager + Let's Encrypt | ACM | Both automatic |
| **CI/CD** | ARC runners (existing) | GitHub Actions | Same workflow, different deploy target |

### AWS Cost Estimates (Serverless)

| Scale | Monthly Cost |
|-------|-------------|
| 1 user (dev) | ~$0.50 (Route53 only) |
| 10 users | ~$4 |
| 100 users | ~$34 |

**Key decision**: DynamoDB over Aurora Serverless v2 — Aurora's $43.80/mo minimum is a budget-killer at low scale. DynamoDB free tier covers 25GB + 25 WCU/RCU permanently.

---

## Phase 1: Security Hardening & Code Audit

**Goal**: Make the codebase safe for deployment and contribution.

| # | Task | Severity | Status |
|---|------|----------|--------|
| 1.1 | Encrypt backup zip files before Google Drive upload (AES-256) | HIGH | TODO |
| 1.2 | Implement PKCE for Xero OAuth flow | MEDIUM | TODO |
| 1.3 | Implement PKCE for ChatGPT OAuth flow | MEDIUM | TODO |
| 1.4 | Add OAuth state parameter validation in redirect handlers | MEDIUM | TODO |
| 1.5 | Add input length validation to all TextFormField widgets | MEDIUM | TODO |
| 1.6 | Replace `flutter_secure_storage` beta with stable release | LOW | TODO |
| 1.7 | Extract hardcoded Sentry DSN to runtime config | LOW | TODO |
| 1.8 | Extract hardcoded Google OAuth client IDs to runtime config | LOW | TODO |
| 1.9 | Run `flutter pub outdated` and update stale dependencies | LOW | TODO |
| 1.10 | Review upstream license — verify fork and contribution rights | — | TODO |
| 1.11 | Run `flutter analyze` — fix all warnings and dead code | — | TODO |

**Deliverable**: All HIGH/MEDIUM security issues resolved. Public repo protections complete.

---

## Phase 2: Architecture Cleanup & Design System

**Goal**: Fix structural problems before building new features. Establish the Apple design system foundation.

### 2A: State Management & Architecture

| # | Task | Status |
|---|------|--------|
| 2A.1 | Choose ONE state management solution (Riverpod recommended over June/Provider mix) | TODO |
| 2A.2 | Extract business logic from DAOs into Service classes (JobService, InvoiceService, QuoteService) | TODO |
| 2A.3 | Add transaction safety — Service layer wraps multi-DAO operations in DB transactions | TODO |
| 2A.4 | Fix global June state pollution — scope form state to edit screens, not globals | TODO |
| 2A.5 | Replace 91 FutureBuilderEx instances with proper async state (AsyncValue/Riverpod) | TODO |
| 2A.6 | Add form dirty-state tracking + "Unsaved changes" confirmation dialog | TODO |
| 2A.7 | Add search debouncing (300ms) to all search fields | TODO |
| 2A.8 | Add pagination/virtual scrolling to all entity lists | TODO |

### 2B: Design System Foundation

| # | Task | Status |
|---|------|--------|
| 2B.1 | Create `lib/design_system/` with tokens (colors, typography, spacing, radius) | TODO |
| 2B.2 | Build `GroupedListSection` widget (iOS Settings-style rounded sections) | TODO |
| 2B.3 | Build `FormFieldRow` widget (label + input in grouped list row) | TODO |
| 2B.4 | Build `StatusBadge` widget (colored pills: green=paid, yellow=sent, red=overdue) | TODO |
| 2B.5 | Build `StatCard` widget (for dashboard metrics) | TODO |
| 2B.6 | Build `EmptyState` widget (icon + title + subtitle + CTA button) | TODO |
| 2B.7 | Build skeleton/shimmer loading states for lists and detail screens | TODO |
| 2B.8 | Switch app root from MaterialApp to CupertinoApp | TODO |
| 2B.9 | Implement light + dark mode with semantic color tokens | TODO |
| 2B.10 | Replace toast-only errors with inline field validation (systemRed, footnote size) | TODO |

**Deliverable**: Clean architecture with Service layer. Apple design system atoms/molecules ready. Dark mode.

---

## Phase 3: Build, CI/CD & K3s Deployment

**Goal**: Independent build pipeline, running in k3s for browser testing.

| # | Task | Status |
|---|------|--------|
| 3.1 | Fork or vendor `booking_request` and `calendar_view` (onepub.dev deps) | TODO |
| 3.2 | Verify `flutter build web --release` succeeds cleanly | TODO |
| 3.3 | Create Dockerfile (multi-stage: Flutter build → nginx serve with /healthz) | TODO |
| 3.4 | Build amd64 Docker image (`--provenance=false`) and push to Harbor | TODO |
| 3.5 | Create GitHub Actions CI workflow (test, analyze, format, build) | TODO |
| 3.6 | Create k8s manifests (Namespace, Deployment, Service, Ingress) | TODO |
| 3.7 | Deploy to `hmb.k3s.internal.strommen.systems` | TODO |
| 3.8 | Add ServiceMonitor for nginx metrics (Prometheus) | TODO |
| 3.9 | Test SQLite WASM persistence in browser | TODO |
| 3.10 | Test graceful degradation of mobile-only features (camera, dialer) | TODO |

**Deliverable**: Green CI pipeline. HMB accessible at `hmb.k3s.internal.strommen.systems`.

---

## Phase 4: UX Overhaul — Apple-Quality Screens

**Goal**: Rebuild every major screen using the design system. This is where the app goes from "developer tool" to "product."

### 4A: Navigation & Shell

| # | Task | Status |
|---|------|--------|
| 4A.1 | Replace HomeScaffold wrapping with proper CupertinoTabScaffold (5 tabs: Jobs, Customers, Invoices, Dashboard, Settings) | TODO |
| 4A.2 | Implement large title → inline title collapse on scroll | TODO |
| 4A.3 | Add global search (pull-down search bar in nav, searches across all entities) | TODO |
| 4A.4 | Add long-press context menus on list items (Edit, Call, Navigate, Complete, Delete) | TODO |
| 4A.5 | Add swipe actions on lists (leading: Complete, trailing: Delete/Archive) | TODO |

### 4B: Dashboard

| # | Task | Status |
|---|------|--------|
| 4B.1 | Design Apple-style dashboard: greeting hero + stat cards + today's schedule + activity feed | TODO |
| 4B.2 | Stat cards: Jobs Today, Revenue Due, Overdue Invoices, Monthly Revenue | TODO |
| 4B.3 | Today's schedule: timeline-style job list with times | TODO |
| 4B.4 | Activity feed: recent payments, new bookings, completed jobs | TODO |
| 4B.5 | Make stat cards tappable → navigate to filtered list | TODO |

### 4C: Core Screens

| # | Task | Status |
|---|------|--------|
| 4C.1 | Job list: grouped by date (Today/This Week/Later), status dots, customer name | TODO |
| 4C.2 | Job edit: sectioned form (Details, Billing, Schedule, Tasks, Photos) with collapsible sections | TODO |
| 4C.3 | Customer profile: hero header + avatar + quick actions + grouped sections | TODO |
| 4C.4 | Customer list: alphabetical sections, search, swipe-to-call | TODO |
| 4C.5 | Invoice screen: document-style presentation with status badge, line items, totals | TODO |
| 4C.6 | Quote screen: document-style with approval status, amendment history | TODO |
| 4C.7 | Settings: pure iOS Settings clone (grouped list, switches, segmented controls) | TODO |

### 4D: Forms & Input

| # | Task | Status |
|---|------|--------|
| 4D.1 | Replace all forms with grouped-list-row fields (label left, input right) | TODO |
| 4D.2 | Add inline validation errors below fields (systemRed, footnote size) | TODO |
| 4D.3 | Add "Create New" inline option in entity picker dropdowns | TODO |
| 4D.4 | Use CupertinoDatePicker (compact inline style) for all date fields | TODO |
| 4D.5 | Use CupertinoSegmentedControl for 2-4 option fields (billing type, priority) | TODO |
| 4D.6 | Use CupertinoSwitch for all boolean settings | TODO |
| 4D.7 | Implement proper keyboard handling — auto-scroll to focused field | TODO |

**Deliverable**: Every major screen rebuilt with Apple design language. Dark mode working. Feels native.

---

## Phase 5: Multi-AI Provider Support

**Goal**: Abstract AI layer, support multiple providers, enable self-hosted inference.

| # | Task | Status |
|---|------|--------|
| 5.1 | Create `AIProvider` abstract class and `AIProviderFactory` | TODO |
| 5.2 | Refactor existing ChatGPT calls behind `AIProvider` interface | TODO |
| 5.3 | Add OpenRouter provider (default — single key, multi-model routing) | TODO |
| 5.4 | Add Anthropic Claude provider (haiku for extraction, sonnet for vision/reasoning) | TODO |
| 5.5 | Add Ollama provider for self-hosted text inference (connects to k3s Ollama or LiteLLM) | TODO |
| 5.6 | Settings UI — provider selection per workload with model picker | TODO |
| 5.7 | Token usage and cost tracking per provider (stored in SQLite) | TODO |
| 5.8 | Add new AI workloads: quote description generation, email drafting, job cost estimation | TODO |

### Provider Recommendations

| Workload | Best Provider | Model | Why |
|----------|--------------|-------|-----|
| Customer extraction (text → JSON) | Claude | haiku-4-5 | Best structured output, cheapest |
| Job assist (summarization) | Claude | sonnet-4-5 | Strong reasoning |
| Receipt scanning (image → data) | Claude | sonnet-4-5 | Superior vision |
| Quote/email drafting | OpenRouter | varies | Flexible, cost-optimized |
| Budget fallback | OpenAI | gpt-4o-mini | Cheapest cloud option |
| Self-hosted / private | Ollama | llama-3.1-8b | Free, on k3s |

**Deliverable**: Provider-agnostic AI layer. OpenRouter default, Claude/Ollama options.

---

## Phase 6: Invoicing & Quoting Completion

**Goal**: Fix the revenue engine. This is the most business-critical phase.

### 6A: Invoicing Fixes

| # | Task | Status |
|---|------|--------|
| 6A.1 | Add Invoice FSM: Draft → Sent → Paid → Voided (no editing sent invoices) | TODO |
| 6A.2 | Fix task-level billing overrides — FP vs T&M must apply consistently across calculators | TODO |
| 6A.3 | Enforce quote-as-source-of-truth — lock task amounts after quote acceptance | TODO |
| 6A.4 | Add tax calculation per jurisdiction (configurable tax rate) | TODO |
| 6A.5 | Add payment terms (Net 30, Net 60, custom) | TODO |
| 6A.6 | Add duplicate invoice prevention (de-duplication check) | TODO |
| 6A.7 | Prevent editing sent invoices — must void and re-create | TODO |
| 6A.8 | Upgrade PDF template — customizable logo, business details, terms, ABN | TODO |

### 6B: Quoting Fixes

| # | Task | Status |
|---|------|--------|
| 6B.1 | Add quote amendment workflow (revise without rejecting) | TODO |
| 6B.2 | Add per-line quote rejection | TODO |
| 6B.3 | Add quote versioning (v1, v2, v3 with diff) | TODO |
| 6B.4 | Add quote expiry/validity period | TODO |
| 6B.5 | Lock tasks after quote acceptance (no silent scope changes) | TODO |
| 6B.6 | Enforce milestone payment support — milestones only from accepted quotes | TODO |

### 6C: Billing Integration

| # | Task | Status |
|---|------|--------|
| 6C.1 | Separate quoted vs unquoted task invoicing | TODO |
| 6C.2 | Add post-quote unquoted tasks (separately invoiceable) | TODO |
| 6C.3 | End-to-end billing flow tests with fixture data | TODO |

**Deliverable**: Complete quote → invoice → payment lifecycle. Tax support. PDF templates.

---

## Phase 7: Multi-User & Sync Engine

**Goal**: Transform from single-user local app to multi-user synced platform.

### 7A: Sync Schema (Client-Side)

| # | Task | Status |
|---|------|--------|
| 7A.1 | Add `syncId`, `updatedAt`, `deviceId` columns to all entity tables | TODO |
| 7A.2 | Create `_sync_outbox` table (table, recordId, operation, data, timestamp, deviceId) | TODO |
| 7A.3 | Create `_sync_metadata` table (lastSyncTimestamp, deviceId) | TODO |
| 7A.4 | All local writes append to outbox automatically | TODO |

### 7B: API Server (Self-Hosted on k3s)

| # | Task | Status |
|---|------|--------|
| 7B.1 | Create HMB API server (Python FastAPI or Dart shelf) | TODO |
| 7B.2 | Auth integration — Authentik (k3s) with JWT validation | TODO |
| 7B.3 | CRUD endpoints for all entities | TODO |
| 7B.4 | Sync endpoints: `POST /sync/push`, `GET /sync/pull?since={ts}` | TODO |
| 7B.5 | File upload via presigned URLs (MinIO S3-compatible API) | TODO |
| 7B.6 | AI proxy endpoint (routes to LiteLLM/OpenRouter) | TODO |
| 7B.7 | PostgreSQL 16 StatefulSet + Longhorn PVC | TODO |
| 7B.8 | MinIO deployment for object storage | TODO |
| 7B.9 | Deploy to `api.hmb.k3s.internal.strommen.systems` | TODO |
| 7B.10 | Prometheus /metrics + ServiceMonitor | TODO |

### 7C: AWS Serverless (Optional Cloud Target)

| # | Task | Status |
|---|------|--------|
| 7C.1 | Terraform module: `hmb-frontend` (S3 + CloudFront + OAC) | TODO |
| 7C.2 | Terraform module: `hmb-api` (API Gateway HTTP API) | TODO |
| 7C.3 | Terraform module: `hmb-lambda` (CRUD, sync, AI proxy, file presign) | TODO |
| 7C.4 | Terraform module: `hmb-dynamodb` (single-table design + GSIs) | TODO |
| 7C.5 | Terraform module: `hmb-cognito` (User Pool, App Client) | TODO |
| 7C.6 | Terraform module: `hmb-storage` (S3 files bucket, lifecycle rules) | TODO |
| 7C.7 | Environment: `terraform/environments/hmb-dev/` | TODO |

### 7D: Sync Engine (Client-Side)

| # | Task | Status |
|---|------|--------|
| 7D.1 | Implement sync engine — push outbox when online, pull changes | TODO |
| 7D.2 | Conflict resolution — last-write-wins with conflict log for review | TODO |
| 7D.3 | Polling sync (every 30s when online) — simpler than WebSocket | TODO |
| 7D.4 | Offline indicator in UI (connection status badge) | TODO |
| 7D.5 | First sync = full upload of existing local data | TODO |

### 7E: Multi-User

| # | Task | Status |
|---|------|--------|
| 7E.1 | Add User entity with tenant isolation (userId on all records) | TODO |
| 7E.2 | Add Team concept (shared customer/job access) | TODO |
| 7E.3 | Role-based access control: Admin, Crew, Accounting | TODO |
| 7E.4 | Login/registration screens (Cupertino style) | TODO |
| 7E.5 | User profile + business settings | TODO |

**Deliverable**: Multi-user app with offline-first sync. Working on k3s. AWS deployable.

---

## Phase 8: Analytics, Notifications & Integrations

**Goal**: Add the missing "how am I doing?" features and external integrations.

### 8A: Analytics Dashboard

| # | Task | Status |
|---|------|--------|
| 8A.1 | Revenue dashboard: monthly/weekly/daily revenue chart (fl_chart) | TODO |
| 8A.2 | Job pipeline: funnel visualization (Prospecting → Active → Completed → Billed) | TODO |
| 8A.3 | Customer lifetime value ranking | TODO |
| 8A.4 | Time utilization: billable vs non-billable hours | TODO |
| 8A.5 | Profit per job analysis | TODO |
| 8A.6 | Export reports to PDF/CSV | TODO |

### 8B: Notifications

| # | Task | Status |
|---|------|--------|
| 8B.1 | Local notifications: job reminders, overdue invoices, due-today | TODO |
| 8B.2 | Push notifications via server (when syncing) | TODO |
| 8B.3 | Notification preferences in Settings (per-type toggles) | TODO |

### 8C: API & Integrations

| # | Task | Status |
|---|------|--------|
| 8C.1 | REST API for third-party integrations (OpenAPI spec) | TODO |
| 8C.2 | Webhook dispatch on events (job.completed, invoice.paid, quote.approved) | TODO |
| 8C.3 | OpenClaw integration — AI-powered operations (job estimation, customer insights) | TODO |
| 8C.4 | Calendar sync (Apple Calendar, Google Calendar) | TODO |
| 8C.5 | Accounting adapter for QuickBooks (in addition to Xero) | TODO |

### 8D: Quality of Life

| # | Task | Status |
|---|------|--------|
| 8D.1 | Job templates / cloning for recurring work patterns | TODO |
| 8D.2 | Recurring jobs with auto-scheduling | TODO |
| 8D.3 | Bulk operations (mass-invoice, bulk-schedule) | TODO |
| 8D.4 | Advanced filtering (multi-field, saved filters) | TODO |
| 8D.5 | Undo/redo for accidental deletes | TODO |
| 8D.6 | Onboarding wizard with guided first-job creation + sample data | TODO |
| 8D.7 | Customer portal (quote approval, invoice status, payment) | TODO |

**Deliverable**: Full analytics. Notifications. API for integrations. Production-ready CRM.

---

## Self-Hosted vs Cloud Service Map

| Service | Self-Hosted (k3s) | Cloud (AWS) | Notes |
|---------|-------------------|-------------|-------|
| Frontend | nginx + Traefik | CloudFront + S3 | Both trivial |
| API | FastAPI pod | API Gateway + Lambda | Same codebase, different entry point |
| Auth | **Authentik** (existing) | Cognito | Both produce JWTs, API validates generically |
| Database | PostgreSQL 16 | DynamoDB | Different query patterns — abstract behind repository |
| Object Storage | **MinIO** | S3 | MinIO is S3-compatible, same client code |
| AI Proxy | **LiteLLM** (existing) | Lambda → OpenRouter | LiteLLM already deployed on k3s |
| Monitoring | Prometheus + Grafana | CloudWatch | k3s stack already running |
| TLS | cert-manager | ACM | Both automatic |
| DNS | `*.k3s.internal.strommen.systems` | Route53 custom domain | |

**Bold** = already deployed in k3s cluster, zero additional work.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Private onepub.dev deps break builds | Fork/vendor `booking_request` + `calendar_view` in Phase 3 |
| SQLite WASM browser compatibility | Test Chrome/Firefox/Safari; fallback to IndexedDB via drift |
| OAuth redirects don't work in web | Configure web-specific redirect URIs per platform |
| 164 SQL migrations slow app startup | Consider squashing to baseline for fork |
| Cupertino widgets missing grouped list | Build custom `GroupedListSection` early in Phase 2B |
| DynamoDB query limitations vs PostgreSQL | Abstract behind repository pattern; pick DB per environment |
| Upstream diverges significantly | Track upstream main, cherry-pick selectively, don't rebase |
| Mobile-only features in web (camera, dialer) | Platform detection + graceful fallback UI |
| Multi-user refactor touches every table | Add sync columns via migration in Phase 7A before any data model changes |

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-27 | Fork bsutton/hmb to ZoltyMat/hmb | Evaluate for security, extend for our use case |
| 2026-03-27 | Public repo — all secrets must be runtime config | Fork is public, GitHub scanning enabled |
| 2026-03-27 | Apple design language (Cupertino, not Material) | Target Apple-quality polish; grouped lists + semantic colors + whitespace |
| 2026-03-27 | Self-hosted k3s as primary target, AWS as optional | Leverage existing cluster; AWS for production/external users |
| 2026-03-27 | DynamoDB over Aurora Serverless v2 for AWS | $0 vs $43.80/mo minimum; DynamoDB free tier sufficient |
| 2026-03-27 | OpenRouter as default AI provider | Existing account, single key, multi-model, no vendor lock-in |
| 2026-03-27 | Polling sync over WebSocket | Simpler, cheaper, sufficient for CRM workload |
| 2026-03-27 | Build self-hosted versions of all services first | MinIO, Authentik, LiteLLM already deployed; zero additional cost |
| 2026-03-27 | Riverpod over June/Provider mix | Single state management solution; eliminates 3-pattern confusion |
| 2026-03-27 | Service layer between UI and DAOs | Fix god-class DAOs; proper transaction safety; testable business logic |
