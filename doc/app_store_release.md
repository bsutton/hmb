# App Store release preparation (#9)

Status: **not submitted and not ready for submission**. No Apple Developer
membership, App Store Connect app or signing team has been supplied. Preparation
was performed on Linux; it is not an iOS build or device validation.

## Repository audit

- Runner uses `ios/Runner/Info.plist`, not the loose `ios/Info.plist` fragment.
  Camera/photo purpose strings and URL/query schemes now live in the active
  plist. The old fragment is retained for history but is not built.
- Current bundle identifier is `dev.onepub.handyman`; confirm ownership and
  availability before registering it. Do not invent or commit a signing team.
- No iOS Podfile, Swift Package Manager integration or app privacy manifest was
  found in this checkout. Resolve native plugin integration on the release Mac
  using the installed Flutter version and verify every plugin's supported iOS
  target. Do not assume the existing 12.0 deployment target is sufficient.
- Audit release icons and launch images on a device; files existing in the asset
  catalog does not establish that they are approved release branding.
- No microphone/background-location purpose strings were added without a
  corresponding feature. The separate #18 branch adds foreground trip location
  permission; include and retest it when preparing the integrated release.

## Owner decisions and access

1. Enrol in the Apple Developer Program and decide the individual/organisation
   account and public seller identity. The owner must accept agreements/pay fees.
2. Register the confirmed bundle ID and create the App Store Connect app.
3. Provide authorized signing access on a Mac; keep certificates, private keys,
   provisioning profiles and API keys out of Git.
4. Approve product name, description, category, territories, price, support URL,
   privacy policy, screenshots and age-rating answers.
5. Review distribution rights and the repository's licence restrictions before
   publication. No licence or legal declarations have been changed here.

## Privacy and integration review

Do not claim “no data collected” from the presence of a local database. Review
the actual release configuration and every SDK. HMB includes customer/contact
details, photos, financial records, backups, error reporting and optional
external integrations. Confirm which information leaves the device, who receives
it, retention, user controls and the matching App Store privacy responses.

Generate and review Xcode's privacy report. Verify required-reason API entries
and bundled SDK manifests from the actual archive; do not copy guessed reason
codes or data-collection declarations into a manifest. Check Sentry, Google,
accounting, AI and email integrations against the final release configuration.

Review OAuth redirects on iOS. A custom URL declaration alone does not configure
HTTPS Universal Links, associated domains or an OAuth provider's registered
callback. Verify Google/Xero/other enabled sign-in flows end to end. QuickBooks
preview authorization and live tax checks are separately pending under #15.

## Build and device gates (Mac required)

1. Use the final integrated commit, resolve all migration manifests, and run
   `flutter pub get`, `flutter analyze`, and `flutter test`.
2. Open `ios/Runner.xcworkspace` in supported Xcode. Resolve native dependencies,
   minimum deployment target, capabilities, signing and build configuration.
3. Run on an iPhone and iPad: fresh install, upgrade with sanitized existing
   data, camera/gallery permission grant and refusal, phone/email/SMS actions,
   PDFs/share, secure storage, backup/restore, notifications and OAuth callbacks.
4. Test optional trip recording and its permission refusal, foreground lifecycle
   and Google opt-in. Test offline paths and startup without integrations.
5. Build with `flutter build ipa --release` using the approved version/build
   number. Inspect and validate the archive and its privacy report in Xcode.
6. With owner approval, upload to App Store Connect and distribute through
   TestFlight. Review crashes, upgrade behaviour, accessibility and layout.
7. Supply review instructions/sample data without real customer information.
   Submit for review only after the owner approves the listing and build.

## Completion criteria

Keep #9 open until an approved build is actually published. Static plist checks,
a prepared branch or a successful archive are not equivalent to App Store
publication. No account, app listing, upload, submission or purchase was made.

Sources: [Flutter iOS release guide](https://docs.flutter.dev/deployment/ios),
[Apple app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy),
[privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files),
[required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
