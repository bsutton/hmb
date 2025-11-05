# Repository Guidelines

## Project Structure & Module Organization
The Flutter app code lives in `lib/`, split into feature modules, database management, and shared widgets. Tests mirror that layout under `test/`, with SQL fixtures inside `test/sql`. Platform scaffolding resides in `android/`, `ios/`, `linux/`, `macos/`, `web/`, and `windows/`. Assets are kept under `assets/` while marketing collateral sits in `marketing/` and `blog/`; keep generated build artifacts inside `build/` out of version control. Tooling scripts are in `tool/`, including `tool/lib/` helpers that the build pipeline relies on.

## database migrations 
Migrations are done via raw sql scripts for sqllite on android 11+ and are stored in `assets/sql/upgrade/scripts`. The tool/build.dart --assets command adds a new script to the `assets/sql/upgrade_list.json`

## Build, Test, and Development Commands
Run `flutter pub get` after cloning or when dependencies change. Use `flutter run` to launch the app on a connected device or emulator. `dart run tool/build.dart --assets --build --install` refreshes the asset manifest, builds an APK, and sideloads it—omit flags to limit steps. For release artifacts, use `dart run tool/build.dart --release`; it bumps versions and strips unused WASM modules before building an app bundle.

## Coding Style & Naming Conventions
Follow Dart's 2-space indentation and keep lines under 80 characters. Use `dart format .` before committing and ensure `flutter analyze` passes; the repo inherits rules from `analysis_options.yaml` via `package:lint_hard`. Name classes and enums in PascalCase, public members and locals in lowerCamelCase, and constants with a leading `k`. Keep widgets small and composable, and place shared theming or utilities in existing directories instead of duplicating helpers.

## Testing Guidelines
Add unit and widget tests beside the code under `test/feature/...`, naming files `*_test.dart`. Use `flutter test` for the full suite or target directories, e.g., `flutter test test/dao`. Database migrations should include a fixture in `test/sql/` and an assertion that the DAO reads it correctly. Aim to cover new branches and side effects, especially around job status and invoicing flows.

## Commit & Pull Request Guidelines
Use short, imperative commit subjects (for example, `Add invoice margin calculator`) and include context in the body when touching multiple layers. Group unrelated changes into separate commits to keep reviews focused. Pull requests should describe the change, reference GitHub issues, and include before/after screenshots for UI updates. Confirm that `flutter test` and `flutter analyze` pass before requesting review and call out any follow-up tasks in the description.

## Security & Configuration Tips
Keep the signing keys in `hmb-production.keystore*` and `hmb-debug.keystore*` private; never upload replacements to external storage. Store environment-specific credentials in your local `database/` backups and avoid committing SQLite exports. When handling customer data in demos, scrub personal details before checking fixtures into `test/` or `assets/`.
