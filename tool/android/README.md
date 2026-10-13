# Android APK startup validation

After building an APK, check that its enabled manifest components exist in DEX:

```sh
python3 tool/android/check_apk_components.py \
  build/app/outputs/flutter-apk/app-release.apk \
  --apkanalyzer "$ANDROID_HOME/cmdline-tools/latest/bin/apkanalyzer"
```

This is an artifact check, not a substitute for launching the release build on
Android. Flutter tests and `flutter build bundle` do not validate native Android
component packaging.

The local 0.46.5 (328) APK examined on 14 October 2026 declared
`com.sidlatau.flutteremailsender.FlutterEmailSenderFileProvider`, but omitted that
class from both the plugin classes JAR and final DEX. Android instantiates enabled
providers before starting the activity, so this defect can prevent startup before
Dart error handling runs. The source file existed, but Gradle incorrectly regarded
the incomplete compiled output as up to date. Explicit recompilation restored it:

```sh
cd android
./gradlew :flutter_email_sender_method_channel:compileReleaseKotlin --rerun-tasks
```

Rebuild the APK after recompilation and run the artifact check again. Keep the
existing signing configuration. Do not uninstall the app or clear its data as a
workaround. An update of an existing installation must preserve the package ID,
signing identity and user data. Obtain device crash logs and verify startup before
calling the phone regression resolved.
