# Requirements: Job + Quote Event-Driven FSM

Related issues: `#248`, `#249`

## 1. Problem Statement

Current lifecycle behavior is split across UI, DAO, and FSM code:

- Job lifecycle is partially FSM-driven (`lib/fsm/job_status_fsm.dart`) but
  still has direct status mutation paths in DAO/UI (`DaoJob.mark*`,
  `job.status = ...`, `DaoJob().update(job)`).
- Quote lifecycle has no FSM equivalent; UI and DAO methods directly execute
  state changes and side effects (`approveQuote`, `rejectQuote`,
  `withdrawQuote`, `markQuoteSent`).
- Buttons in UI frequently call process methods directly rather than raising
  lifecycle events.

This creates drift, duplicated rules, and side effects that are difficult to
audit and test.

## 2. Core Principle

All lifecycle transitions must be event-driven:

- UI emits a domain event.
- FSM validates transition and decides target state.
- Side effects are executed by transition handlers (not UI).
- Persistence is performed by lifecycle services invoked by FSM handlers.

No component may directly set lifecycle state as a shortcut.

## 3. Scope

In scope:

- Job lifecycle transition architecture and enforcement.
- Quote lifecycle FSM introduction.
- Refactor UI actions to dispatch events.
- Move transition side effects behind FSM handlers.
- Add transition history/audit support.

Out of scope:

- Invoicing calculation redesign.
- Non-lifecycle CRUD concerns.

## 4. Mandatory Rules

1. State can only change via a lifecycle event dispatcher.
2. Direct writes to `job.status` and `quote.state` are prohibited outside
   dedicated lifecycle infrastructure.
3. UI components may request transitions but must not run lifecycle side
   effects.
4. Transition handlers must be idempotent where practical.
5. Every transition must be testable by:
   - allowed/blocked transition tests
   - side-effect tests
   - persisted state validation

## 5. Target Architecture

## 5.1 Components

- `JobLifecycleMachine` (FSM)
- `QuoteLifecycleMachine` (FSM)
- `LifecycleEventDispatcher` (single entry point)
- `LifecycleCommandHandler` (side effects + persistence)
- `LifecycleRepository` (DAO wrapper for lifecycle writes)
- `LifecycleAuditRepository` (transition log)

## 5.2 Event Flow

1. UI calls dispatcher with `EntityId + Event + Context`.
2. Dispatcher loads current aggregate snapshot.
3. FSM checks guard and computes transition.
4. Handler executes side effects in transaction boundary.
5. Repository persists new state and metadata.
6. Audit entry is written with event, from/to state, actor, timestamp.

## 5.3 Transaction Model

- Each lifecycle event executes in one transactional unit where possible.
- Side effects affecting related entities (e.g. reject job -> reject quotes ->
  void milestones) must be orchestrated as one command chain.

## 6. Proposed Event Model

## 6.1 Job Events (minimum)

- `job.start_quoting`
- `job.quote_submitted`
- `job.quote_approved`
- `job.payment_received`
- `job.schedule_requested`
- `job.work_started`
- `job.pause_requested`
- `job.resume_requested`
- `job.materials_arrived`
- `job.complete_requested`
- `job.invoice_raised`
- `job.reject_requested`

## 6.2 Quote Events (minimum)

- `quote.send_requested`
- `quote.approve_requested`
- `quote.unapprove_requested`
- `quote.reject_requested`
- `quote.withdraw_requested`
- `quote.invoice_marked`

## 6.3 Context Payload

Common payload fields:

- `actorId` / system actor
- `reason` / note
- `requestedAt`
- `source` (ui, automation, migration, api)

Specialized fields:

- `rejectScope` (`quote_only`, `quote_and_job`)

## 7. Transition Side Effects (examples)

Quote:

- `send_requested`:
  - set quote state `sent`, set `date_sent`
  - dispatch `job.quote_submitted` (or equivalent coupling event)
- `reject_requested`:
  - set quote `rejected`
  - void milestones
  - if `rejectScope=quote_and_job`, dispatch `job.reject_requested`

Job:

- `reject_requested`:
  - set job `rejected`
  - reject open/approved quotes
  - void milestones when required
- `complete_requested`:
  - close linked open todo items

## 8. Enforcement Requirements

1. Add lifecycle service interfaces and route all existing calls through them.
2. Deprecate direct DAO state mutators (`DaoJob.mark*`, `DaoQuote.updateState`
   style calls) or make them internal/private to lifecycle layer.
3. Add lint/static checks (or test grep) to block new direct writes to
   `job.status` / `quote.state`.
4. Replace UI direct-action buttons with event dispatch:
   - `quote_card.dart`
   - quote details actions
   - job status dialogs and pickers

## 9. Migration Plan

Phase 1: Infrastructure

- Introduce dispatcher, command handlers, audit schema/table.
- Build `QuoteLifecycleMachine` with existing states.

Phase 2: Job unification

- Route all job transitions through dispatcher.
- Remove/lock direct status mutation pathways.

Phase 3: Quote unification

- Route quote actions (`approve/reject/withdraw/send/unapprove`) via FSM.
- Move all quote side effects into handlers.

Phase 4: UI integration

- Refactor buttons to emit events only.
- Surface allowed transitions from FSM for rendering.

Phase 5: hardening

- Add complete transition matrix tests.
- Add regression tests for milestone/quote/job coupled behavior.

## 10. Acceptance Criteria

1. No production code path directly sets `job.status` or `quote.state` outside
   lifecycle handlers.
2. Every user-facing lifecycle action dispatches an FSM event.
3. Quote FSM exists and is used for all quote transitions.
4. Coupled side effects (quotes, milestones, todos, job status) are executed
   from transition handlers only.
5. Full lifecycle test suite passes, including guard and side-effect cases.
6. Transition audit records are written for all successful transitions.

## 11. Open Design Decisions

1. Single combined lifecycle engine vs separate job/quote engines with
   cross-dispatch.
2. Event sourcing-lite (append-only transition log) vs simple audit table.
3. Whether to expose transition history in UI immediately or later.

