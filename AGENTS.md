# Repository Guidelines

## Project Structure & Module Organization
The Flutter app code lives in `lib/`, split into feature modules, database management, and shared widgets. Tests mirror that layout under `test/`, with SQL fixtures inside `test/sql`. Platform scaffolding resides in `android/`, `ios/`, `linux/`, `macos/`, `web/`, and `windows/`. Assets are kept under `assets/` while marketing collateral sits in `marketing/` and `blog/`; keep generated build artifacts inside `build/` out of version control. Tooling scripts are in `tool/`, including `tool/lib/` helpers that the build pipeline relies on.

## database migrations 
Migrations are done via raw sql scripts for sqllite on android 11+ and are stored in `assets/sql/upgrade/scripts`. The tool/build.dart --assets command adds a new script to the `assets/sql/upgrade_list.json`

## Build, Test, and Development Commands
Run `flutter pub get` after cloning or when dependencies change. Use `flutter run` to launch the app on a connected device or emulator. `dart run tool/build.dart --assets --build --install` refreshes the asset manifest, builds an APK, and sideloads it—omit flags to limit steps. For release artifacts, use `dart run tool/build.dart --release`; it bumps versions and strips unused WASM modules before building an app bundle.

## Coding Style & Naming Conventions
Follow Dart's 2-space indentation and keep lines under 80 characters. Use `dart format .` before committing and ensure `flutter analyze` passes; the repo inherits rules from `analysis_options.yaml` via `package:lint_hard`. Name classes and enums in PascalCase, public members and locals in lowerCamelCase, and constants with a leading `k`. Keep widgets small and composable, and place shared theming or utilities in existing directories instead of duplicating helpers.

## Standard HMB UI Components
Before adding a Material widget or a one-off control, check `lib/ui/widgets/`
for an existing HMB component and use it whenever possible. This includes
buttons, fields, selectors, cards, surfaces, layout helpers, and loading UI.
Keeping these controls shared preserves consistent spacing, validation,
theming, accessibility, and responsive behaviour across the app.

Use `BlockingUI` for asynchronous work that may block interaction. The
application installs the shared `BlockingOverlay` in `main.dart`, so screens
must not add bespoke progress bars, loading dialogs, or literal `Loading...`
placeholders for these operations. Use `BlockingUI().runAndWait(...)` for an
action and `BlockingUITransition` for a slow screen or component transition.
Suppress any builder package's default loading placeholder while the global
overlay owns the waiting state.

Use `FutureBuilderEx` rather than Flutter's `FutureBuilder` for asynchronous
widget content. Supply the appropriate explicit waiting and error builders;
do not allow package defaults such as literal `Loading...` text to become part
of the application UI.

For stateful widgets that require asynchronous initialization, extend
`DeferredState` and perform the work in `asyncInitState`. Use
`DeferredBuilder` to render the initialized state. Do not start asynchronous
initialization from `initState` and call `setState` when it completes.

`DaoSystem().get()` returns an immutable `SystemConfiguration` without
encrypted integration credentials. Use `getForUpdate()` followed by
`updateConfiguration()` only when changing ordinary system settings. Read and
write credentials through the integration-specific methods on `DaoSystem`;
never add secrets to `SystemConfiguration` or restore whole-system secret
hydration.

## Testing Guidelines
Add unit and widget tests beside the code under `test/feature/...`, naming files `*_test.dart`. Use `flutter test` for the full suite or target directories, e.g., `flutter test test/dao`. Database migrations should include a fixture in `test/sql/` and an assertion that the DAO reads it correctly. Aim to cover new branches and side effects, especially around job status and invoicing flows.

## Sidecar Agent Delegation
Use a cheaper sidecar agent for bounded, repeatable checks when the main task is
active HMB development. The main agent keeps ownership of code changes, product
decisions, diff review, and final commit scope.

Good sidecar tasks include:
- running focused `flutter test` or `dart test` commands and reporting exact
  pass/fail output,
- running `dart analyze` or `flutter analyze` on named files,
- collecting fdb screen descriptions, screenshots, and logs without changing
  app state beyond the requested smoke path,
- summarising Git status, changed files, or diff stats,
- inspecting SQLite rows for named tables/ids and reporting results,
- checking documentation consistency for a named feature,
- collecting CI logs and summarising failures.

Do not delegate design choices, schema decisions, customer-data interpretation,
risky edits, route/validation policy decisions, or keep/revert decisions.
Sidecar workers must not edit files, revert changes, reset Git state, or stage
files unless explicitly asked to perform a narrowly scoped commit.

For delegated commits, the main agent must provide the exact file list and
commit message. The sidecar must stage only those files, inspect
`git diff --cached`, create the commit, and report the new commit hash.

Sidecar reports should include:
- the latest commit and worktree status,
- each command run and pass/fail status,
- relevant fdb screen/log snippets or DB query results,
- any command failures or skipped checks.

## Plasterboard Layout
Before changing the plasterboard layout generator, plasterboard layout UI, or
plasterboard PDF output, read
`doc/plasterboard_layout_requirements.md` and treat it as the canonical layout
intent for sheet direction, edge-piece minimums, and related layout rules.

## Commit & Pull Request Guidelines
Use short, imperative commit subjects (for example, `Add invoice margin calculator`) and include context in the body when touching multiple layers. Group unrelated changes into separate commits to keep reviews focused. Pull requests should describe the change, reference GitHub issues, and include before/after screenshots for UI updates. Confirm that `flutter test` and `flutter analyze` pass before requesting review and call out any follow-up tasks in the description.

## Security & Configuration Tips
Keep the signing keys in `hmb-production.keystore*` and `hmb-debug.keystore*` private; never upload replacements to external storage. Store environment-specific credentials in your local `database/` backups and avoid committing SQLite exports. When handling customer data in demos, scrub personal details before checking fixtures into `test/` or `assets/`.
