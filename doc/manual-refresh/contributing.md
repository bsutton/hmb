# Contributing

Use the [HMB repository](https://github.com/bsutton/hmb),
[issues](https://github.com/bsutton/hmb/issues) and
[discussions](https://github.com/bsutton/hmb/discussions).
Read its AGENTS.md before changing code.

HMB uses Dart, Flutter and SQLite. Resolve dependencies with `flutter pub get`.
The current checkout includes private hosted dependencies and a PDF path override
at `../pdf/pdf`; a stock clone needs access to those dependencies and the sibling
PDF checkout. Never commit credentials or signing keys to resolve setup issues.

Database scripts live in `assets/sql/upgrade_scripts/`; the manifest is
`assets/sql/upgrade_list.json`. Register new migration assets using
`tool/build.dart --no-build --no-install`. Coordinate migration numbering and
preserve already released migrations.

Run root tests and, for whole-repository analysis, first resolve dependencies in
`packages/room_editor/example` and run its tests too. Platform-specific setup and
signing may be needed for an installed build. Platform source folders alone are
not evidence that all targets are supported releases.
