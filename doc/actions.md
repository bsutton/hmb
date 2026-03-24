# Combined Feature Plan: #193 + #104

## Job Activity Timeline

Unify action tracking and conversation notes into a single
`Job Activity Timeline` feature.

1. Define scope (single source of truth)
- One timeline per job (customer rollup can come later).
- Each entry is an `ActivityNote` with:
  - `timestamp`
  - `type` (call, email, sms, visit, quote follow-up, schedule update,
    general note)
  - `summary` (short action label)
  - `details` (optional free text conversation notes)
  - `createdBy`/`source` (`manual` or `system`)
  - optional `linkedTodoId`
  - `job_id` (all activities belong to a job)

2. Database + DAO
- Add table `activity` with:
  - `id`
  - `job_id`
  - `occurred_at`
  - `type`
  - `summary`
  - `details`
  - `source`
  - `linked_todo_id` (nullable)
- Indexes:
  - `job_id, occurred_at DESC`
  - `linked_todo_id`
- No join table is required because every activity belongs to one job.
- DAO methods:
  - `insertActivityNote`
  - `listByJob(jobId, {limit, before})`
  - `updateActivityNote`
  - `deleteActivityNote`

3. Manual capture UX (MVP)
- Add `Add Activity` action on job screens.
- Dialog fields:
  - Type picker
  - Summary (required)
  - Details (optional)
  - Date/time (default now)
  - `Create follow-up To Do` toggle
- Show timeline in reverse chronological order on job detail.

4. Templates for fast entry
- Provide quick templates for common actions:
  - `Followed up on quote`
  - `Scheduled visit`
  - `Called customer`
  - `Sent invoice reminder`
- Template pre-fills type + summary, user can still edit details.

5. System-generated actions (phase 2)
- Auto-write timeline entries for key events:
  - quote sent/amended/rejected/accepted
  - invoice created/sent/paid
  - job scheduled/rescheduled/completed
- Mark as `source=system`.

6. To Do integration
- Allow `Create To Do` from any activity note.
- Store backlink from todo to activity note.
- Show linked todo status in timeline.

7. Filtering + usability
- Filters: `All`, `Manual`, `System`, `Calls`, `Emails`, `Notes`.
- Search summary/details.

8. Rollout strategy
- Ship as 2 PRs under one umbrella feature:
  - PR1: DB/DAO + manual notes + timeline UI + templates.
  - PR2: system event hooks + todo linkage.

9. Testing plan
- DAO tests: CRUD, ordering, pagination/filtering.
- Widget tests: add/edit/delete note, template use, todo creation.
- Integration tests: system events create timeline entries.

10. Acceptance criteria
- Timestamped conversation notes in order (#104).
- Action tracking without requiring full communication content (#193).
- Clear recent interaction history on the job.
- Fast entry via templates.
- Optional follow-up todo creation from an activity note.
