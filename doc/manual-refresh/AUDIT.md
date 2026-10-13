# HMB manual audit and handoff

## Baseline and delivery

Reviewed all 31 public manual pages listed by
<https://hmb.onepub.dev/llms.txt>, retrieved 2026-10-12 UTC, against HMB main
`51a4d8e6846fedde31955cbdcc9c484ed44b5138` (`pubspec.yaml` version `0.42.0`).
This is a source baseline, not confirmation of the version currently in Play Store.

App repository: <https://github.com/bsutton/hmb>, existing checkout
`/home/bsutton/git/hmb`. That checkout has unrelated edits and was not changed.
Review worktree: `/home/bsutton/Documents/Codex/2026-10-13/task-4/hmb-docs`,
branch `docs/manual-refresh`. Its Git common directory belongs to the isolated
local clone at `../hmb-doc-review`; keep that clone while using this worktree.
The clone's origin is the local source checkout; do not push this branch there.

Published documentation: <https://hmb.onepub.dev>, GitBook organisation
`ecaaU3OrP2aDt9qZRymk`, space `220StKpP9uprvGvta4QY`, site `site_W6ARh`.
**Git Sync repository, branch and root remain unverified.** No HMB manual or
GitBook config was found in the app checkout or nearby repositories, and the
accessible GitHub repository inventory did not reveal a separate HMB manual repo.
`bsutton/handyman` is a separate server/project repository, not confirmed as the
manual. No guessed repository was edited. See [GitBook discovery](GITBOOK_DISCOVERY.md) for exhausted read-only checks
and the exact remaining maintainer action. Public source/edit metadata is absent;
there is no connected browser to inspect the authenticated settings.

The pages in this directory preserve public page slugs for easy transfer into the
real source once located. They are local review staging, not an active GitBook
configuration. The original downloaded snapshots remain outside the app worktree
at `../published-manual`. No push, merge, publication or deployment occurred.

## Principal findings

- README called quotes planned and invoices/quotes partially working, despite
  current implementation. Rewritten with current scope and preview boundaries.
- Old manual says HMB does not track invoices. Current local debtor ledger,
  customer payments, allocation, adjustments and reporting require new guidance.
- Fixed Price was incorrectly called Cost Plus; task-level mixed billing,
  approval, milestone and direct-invoice scope needed explanation.
- Unsafe blanket advice to delete/recreate invoices and claims that final invoices
  complete all tasks were removed. Current lifecycle actions depend on state.
- Invoice billing contact is stored with the invoice; it does not silently follow
  later job contact edits. Main's View/Send still requires a primary job contact.
- Navigation has changed to Home, Accounting and Settings dashboards. Settings is
  split into Business, Contact, Billing, Storage, Integrations and other pages.
- Credentials use a secure-storage backend; old plain system-table guidance is
  obsolete. Restore should not promise to recover device-held credentials.
- Receipt editing is now a multi-step capture/lines/totals/allocation/link flow.
- Contributor links pointed to the wrong repository, migration paths were wrong,
  and the private dependencies/PDF sibling requirement were missing.
- The Tasks page included an expired signed GitHub image URL. Removed it.
- Privacy's local-only/no-access claim is not established by current source.
  `lib/main.dart` initializes Sentry and replay sampling; optional integrations
  transfer data. The staged privacy page now provides a factual data-flow description with a
  [source register](PRIVACY_EVIDENCE.md), separating startup/resume defaults from
  user-triggered actions. Provider retention/access/masking remain owner questions.

## Page-by-page disposition

Paths below are relative to this directory. “Rewritten” means prose checked
against implementation; it does not mean end-to-end device or integration testing.

| Published page | Disposition and source evidence |
| --- | --- |
| home.md | Rewritten; `lib/ui/nav/dashboards/main/home_dashboard.dart`, HomeScaffold, README |
| prerequisite.md | Rewritten; Android `minSdk = 30`; release/closed-beta availability deferred |
| getting-started.md | Rewritten; settings dashboard and job workflow |
| jobs.md | Rewritten; job/task billing defaults, stored invoice contact; `doc/job_parties.md` |
| tasks.md | Rewritten; `TaskItemType`, task editing and list membership |
| tasks/photos.md | Rewritten from TaskEditScreen/PhotoCrud/PhotoCarousel; pending-photo and zoom correction; fresh camera-control render |
| tasks/time-tracking.md | Rewritten from timer/stop dialog source; fresh start, active and stop-review renders |
| shopping-list.md | Rewritten; `list_shopping_screen.dart`, purchase/hire/consumable types and modes |
| packing-list.md | Rewritten; `list_packing_screen.dart`; stock/owned item membership |
| customers.md | Rewritten from customer editor and job-party implementation; required/default rate, billing role and mailing exclusion corrected |
| suppliers.md | Rewritten from supplier editor, linked contacts/sites and shopping filters; no payment/send claim |
| accounting.md | Rewritten; accounting and reporting dashboard source; fresh report capture |
| accounting/quoting.md | Rewritten; `quote_card.dart`, quote lifecycle/approval and billing rules |
| accounting/quotes-estimates.md | Rewritten; task-level scope and estimate/quote distinction |
| accounting/quotes-estimates/quoting-a-job.md | Rewritten; mixed-job scope and fixed-price items |
| accounting/quotes-estimates/quoting-a-job/elements-a-quote.md | Rewritten; item types, line charges, actuals |
| accounting/quotes-estimates/estimating-a-job.md | Rewritten; fixed-price labour vs T&M time entries |
| accounting/quotes-estimates/estimating-a-job/elements-of-an-estimate.md | Rewritten; matching pricing guidance |
| accounting/quotes-estimates/user-stories.md | Replaced design speculation with bounded pricing example |
| accounting/invoicing.md | Rewritten; create/select/edit/send invoice implementation and ledger |
| accounting/invoicing/time-and-materials-cost-plus.md | Rewritten; progressive eligibility, time entries and booking fee |
| accounting/invoicing/fixed-price.md | Rewritten; direct/quote/milestone scope; no automatic completion promise |
| accounting/invoicing/integration.md | Rewritten; Xero and QuickBooks preview boundary |
| accounting/invoicing/integration/xero.md | Rewritten; actual configuration fields and contact/upload gate; live setup untested |
| accounting/receipt-capture.md | Rewritten; five editor steps and allocations/matching |
| system.md | Rewritten as Settings; secure storage and integration navigation; fresh capture |
| system/logos.md | Rewritten; display boxes distinguished from input pixel constraints; fresh logo controls and Save renders |
| backups.md | Rewritten; actual Backup/Sync Photos/Backup Local controls and success checks |
| restoring.md | Rewritten; Restore control and post-restore checks; timing promise removed |
| contributing.md | Rewritten; repository, migration assets, dependencies and validation |
| privacy.md | Factual local/cloud/default/trigger data-flow description plus explicit unverified policy details |

Existing `doc/invoicing.md` remains explicitly a forward-looking specification;
only its three machine-specific absolute links to `quote.md` were repaired.
Do not treat that specification as proof of completed functionality.

## Captures and replacement result

All 16 old image references have been removed from the staged manual. The final
six were replaced with actual production-widget renders, not drawn mockups:

| Former reference | Replacement |
| --- | --- |
| Photos camera icon | `images/task-photos-main.png`: saved sample task editor scrolled to camera control |
| Timer play icon | `images/timer-start-main.png`: sample task list, Start task timer |
| Active timer screenshot | `images/timer-active-main.png`: actual HomeScaffold status bar and running task card |
| Timer stop icon | `images/timer-stop-main.png`: actual Stop Timer review dialog opened through the stop control |
| Logo upload screenshot | `images/billing-logo-main.png`: current Billing screen scrolled to Logo Aspect Ratio/Upload Logo |
| Logo Save screenshot | `images/billing-save-main.png`: current Billing form and Save/Cancel controls |

Together with `integrations-main.png` and `accounting-reports-main.png`, there are
**eight** fresh PNGs. All are 860 × 1864 (430 × 932 logical pixels, 2×), production
HMB dark theme. See `images/manifest.json` for file hashes and per-capture context.
They render actual app screen widgets; **none is an installed-app screenshot**.
The two original dashboard captures use a title-only harness app bar. Billing and
timer captures use the real HomeScaffold; TaskEditScreen is rendered directly as
it is when pushed by the task list. Scrolled viewports naturally show only part
of long forms. They are not advertised as whole-form or full workflow evidence.

The six new captures use the established temporary test-database helpers.
Displayed settings are sanitized: bank/payment fields blank, no logo, invented
job “Repair demo gate” and task “Replace demo hinges”. Secure storage is mocked
empty. No production backup or customer database is read. Timer state is seeded
rather than starting calendar/location side effects; the stop dialog itself is
opened by its real control. No send/upload/restore/camera action is executed.

Visual inspection confirmed readable labels and icons, no test-font blocks,
no debug ribbon, and no real customer/financial details. Intermediate renders
with test-font blocks were overwritten. Roboto/MaterialIcons replace test fonts;
no PNG was repainted, composited or generated by AI. The task photo and logo images
show controls and blank/sample content, not a fabricated photo capture or upload.

The same widget workflow successfully handled all six references. **No user
action or new device is needed for those replacements.** Desktop runtime would
not establish Android camera/gallery behavior, so no desktop screenshot is
mislabelled as Android. `fdb 1.10.1` found Linux/Chrome only, no Android target.

If installed Android proof is required, the smallest next action is to provide
an already configured Android test device/emulator with disposable sample data.
Then recapture these screens and, separately, native camera/gallery selection,
logo persistence/PDF output, permissions and real app navigation. No emulator
installation, account change or new permission has been performed or requested
as a prerequisite for the current widget documentation.

## Deferred changes and unresolved product questions

- Invoice cleanup #659 remains unmerged in its separate worktree. Its four-file
  invoice presentation/send/export changes were not copied here, and no screenshot
  claims to show that layout. After merge, recapture invoice details/actions,
  invoice line editing, sending and QuickBooks preview against the merged SHA.
- Bunnings demo is fixture-only and unmerged; no normal manual claims were added.
  Any later documentation must be labelled developer prototype with no live API.
- Rust backend work is in progress and is not documented as available.
- Store release version and beta invitation policy cannot be inferred from main.
- Live Xero plan requirements, OAuth setup, delivery, backup restore and sync were
  not exercised. Avoid promising success based on configuration screens alone.
- Source enum `consumablesStock.toPurchase` is true while packing/shopping queries
  explicitly classify stock consumables as packing; prose follows the actual
  screen/query membership. Consider resolving that code-level inconsistency.
- Privacy data fields, masking, retention and operator access need owner review.
- A new `tools.md` covers painting, plasterboard, trip log, inventory, mailings
  and Job Report from actual editor/control source. Full device-based walkthroughs
  and live integration operations remain outside the performed validation.

## Validation

Dependency resolution succeeded with `flutter pub get --enforce-lockfile` after
creating an isolated sibling PDF clone from the existing local checkout (commit
`8fd782b860808187fb68a5e351fbe94c30afa63e`). No dependency files changed.
The app repository's tracked path override is a portability limitation.

The capture sidecar ran:

```sh
FLUTTER_ROOT=/home/bsutton/apps/flutter flutter test --no-pub test/documentation
flutter analyze --no-pub test/documentation
```

Final result: 5 tests passed; analysis reported no issues. Both capture harnesses were
formatted. Production Dart source was not changed; the full application suite was
not rerun for this documentation-only pass.

Run `python3 tool/docs/validate_manual.py` for local targets, fragments, source
evidence paths, image hashes and PNG checks. Run `git diff --check` for whitespace. Final validation passed: 36 Markdown
files, 82 local links, 30 source evidence paths and eight image hashes. Tracked
diff whitespace and all new text files passed; pre-existing whitespace in the
forward-looking `doc/invoicing.md` was preserved.
No actual GitBook source/configuration/build pipeline is available, so the
production build remains blocked by source discovery. The Markdown staging can
be reviewed locally without publishing it.

All 31 published Markdown pages were successfully retrieved. Read-only HTTP checks
returned 200 for the three GitHub links used in the staged user pages and the six
legacy image URLs before those images were replaced. `remote-link-check.json`
retains the historical check without URL tokens; it is not a current image manifest.

Terminal external blockers: (1) maintainer-provided Git Sync repository/branch/root
or confirmation of no sync; (2) owner/service evidence for diagnostics retention,
masking and access before treating the data-flow draft as a complete privacy policy.
Neither prevents reviewing the completed local prose and eight captures.
