# Final Android build validation

Run `tool/build.dart` to refresh assets, clean project outputs, resolve pinned
dependencies, build and validate a release APK, and install it on the selected
Android device. `-a -b -i` remains accepted but is no longer necessary. Each step
is enabled by default and can be disabled independently:

```sh
tool/build.dart                               # assets, build, validate, install
tool/build.dart --no-install                  # assets, build and validate
tool/build.dart --no-assets                   # build, validate and install
tool/build.dart --no-assets --no-build        # install existing APK
tool/build.dart --no-build --no-install       # refresh assets/database only
```

Validation includes component packaging checks and disposable emulator tests.
Installation happens only after these checks pass. Install-only runs reuse a
saved successful validation when the APK's SHA-256 digest is unchanged; they
do not start the emulator or require its tools again. A changed or unrecorded
APK, or a supplied baseline override, goes through validation before installation.
The APK's digest is checked
again immediately before installation. Disabling all three steps does nothing.
`--no-clean` retains incremental compilation; new builds still run all
validation gates.

`tool/build.dart --release` builds an AAB, checks a
bundletool universal APK, checks the union of manifest components and DEX classes
in the emulator-selected split APKs, and installs that split set for runtime tests.
The AAB is copied into `release/` only after validation. No publishing is performed.
Bundle-derived test APKs use a disposable signing key for both versions; the
original AAB and production signing configuration are not modified. Google Play
signing/delivery and other ABI/device combinations still require release testing.
Release mode disables device installation; it honours `--no-assets` and rejects
`--no-build` because it needs to build the release bundle.

## Automatic upgrade baselines

The build tool preserves existing APK and AAB outputs in the ignored
`.android-artifacts/` directory before cleaning. On the first run, the existing
output of the matching type is the upgrade baseline; it must pass the
previous-version startup check. After successful validation, the tested candidate
becomes the baseline for the next build. APK and AAB baselines are independent.
Failed builds and failed validation never advance the last-validated baseline.
The original predecessor is retained alongside the validated artifact.

Artifacts are stored by SHA-256 digest and checked before reuse. This directory
survives `flutter clean`; retain it between builds. No manual copying is needed.
The previous artifact must still have a lower versionCode, and APK upgrades
require matching signing certificates.

On a fresh checkout with no previous output or saved baseline, supply
`--previous-artifact /path/to/last-good.apk` (or `.aab`) once.
`HMB_PREVIOUS_ARTIFACT` also supplies an override; an explicit command-line path
takes precedence. Supplied files are preserved automatically, including files
inside `build/`. There is no validation-skip flag.

## Prerequisites (Linux x86_64)

- Flutter/Dart, dcli, Java, `unzip`, Android SDK command-line tools, platform
  tools and emulator; `ANDROID_HOME` or `android/local.properties` sets SDK path.
- Install the official rootable AOSP image with
  `sdkmanager 'system-images;android-35;default;x86_64'` and accept SDK licenses
  through the normal SDK setup. KVM acceleration is recommended.
- For AABs, set `BUNDLETOOL_JAR` to a verified official
  [bundletool](https://developer.android.com/tools/bundletool) download.

Missing prerequisites, baseline, artifact classes, startup readiness, signature
compatibility or synthetic data all fail the command. Failures are not skips.

## Emulator checks

The runner creates a unique AVD in its own directory, reserves an unused emulator
port and verifies the AVD name before app operations. It never picks a connected
phone or reuses a personal emulator. Only this process is terminated afterward.
Network traffic for the tested app UID is blocked on the disposable emulator.

1. Install the exact candidate APK (or bundle-derived splits), cold-start it,
   require a rendered HMB welcome/dashboard screen, check fatal Java/native/Dart
   logs and observe process survival after readiness.
2. On the same disposable emulator, uninstall the candidate, install the previous
   artifact and confirm readiness. Seed one synthetic customer in its database.
3. Install the candidate with replacement (`-r`), without clearing its data,
   cold-start it, verify database integrity and require that customer to survive.

This exercises migrations actually present between the supplied versions; it does
not invent an older schema when both versions use the same schema. Logs, window
XML and synthetic DB evidence are retained under `build/android-validation/`.
AVD userdata is removed after the run. No customer database is used.
The runner snapshots both input artifacts and records SHA-256 digests for
the originals and every checked APK, including the installed split set, in
`artifacts.json`. Changed input or split bytes fail validation; the build script
checks the candidate digest again immediately before installation/promotion.
The checker and synthetic fixture use Dart libraries already in the dependency
lockfile. No Python interpreter or Python script is used by this suite.

To validate already-built artifacts without a version bump or phone install:

```sh
dart run tool/android_validate.dart /path/candidate.apk /path/previous.apk
```

A successful standalone validation also records the artifact for later
install-only reuse by `tool/build.dart`.

Component-only diagnostic (not a substitute for the full gate):

```sh
./tool/android/check_apk_components.dart \
  --apkanalyzer "$ANDROID_HOME/cmdline-tools/latest/bin/apkanalyzer" \
  /path/to/app.apk
```

For split APKs, pass all selected splits together. The checker covers application/component-factory,
activity, activity-alias targets, service, receiver and provider classes. It skips
explicitly disabled metadata-only components and Android framework classes. It
cannot establish constructor correctness or native library/runtime readiness.
Both executable entry points use `#!/usr/bin/env dcli`; alternatively run them
with `dart run`. Libraries in `tool/lib/` are not standalone scripts.

Focused regression suite:

```sh
flutter test --no-pub test/tool
```

The startup check currently recognizes the English welcome/dashboard screens.
It rejects system overlays and missing readiness, scans fatal Java/native/Dart
log tokens and ANRs, and observes five seconds of process survival. It is a
startup smoke test, not a full application/device/locale compatibility suite.

## Why cleaning alone was insufficient as a policy

The previous `tool/build.dart` ran `flutter pub get` and ordinary incremental
Flutter builds; it called neither Flutter nor Gradle clean. Its "clean test
database" message referred to the SQLite fixture, not Android compilation.
The new project clean removes project outputs, including plugin intermediates;
it does not purge global Pub/Gradle caches. Artifact and runtime validation remain
mandatory, even after clean builds.

The original local 0.46.5 (328) APK omitted the email plugin's FileProvider class
while declaring it in the manifest. Gradle marked the incomplete Kotlin outputs
up to date. Forced recompilation restored the class. Why that incremental state
became incomplete was not established. The user subsequently confirmed the app
starts; the original installed phone artifact and crash stack were not captured.
