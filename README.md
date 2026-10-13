# HMB

HMB (Hold My Beer) helps a solo tradesperson manage customers, jobs and billing.
The Android build requires Android 11 or later. Other platform targets are in the
repository; their presence does not imply a supported production release.

HMB includes customer and supplier records, job/task management, scheduling,
photos, time tracking, shopping and packing lists, estimating, fixed-price quotes,
invoicing, customer payments, receipts and accounting reports. Tasks can inherit
or override a job's billing type, including mixed fixed-price and T&M work.

Optional integrations include Xero, Google Drive backup/photo sync, SMTP email,
Google Calendar, Google Maps, ChatGPT and website booking requests. QuickBooks
Online invoice export is labelled preview. Local records support offline work;
external services and delivery need connectivity and configuration.

A typical workflow is to create a customer and job, add tasks, estimate and quote
when appropriate, schedule the work, shop and pack, record time/materials, then
invoice and record payments. Use only the steps your business needs.

Read the [online manual](https://hmb.onepub.dev). Keep regular off-device database
backups and sync photos separately. For community support, raise an
[issue](https://github.com/bsutton/hmb/issues) or join a
[discussion](https://github.com/bsutton/hmb/discussions).

## Contributing

Read [Repository Guidelines](AGENTS.md) for layout, style and validation.
Run `flutter pub get` before building. Dependencies include private hosted
packages and a PDF path override at `../pdf/pdf`; obtain the appropriate access
and sibling checkout. Keep credentials and signing files private.

Before whole-repository analysis, resolve the room-editor example dependencies:
`flutter pub get --enforce-lockfile --directory packages/room_editor/example`.
Run root tests and the example tests described in AGENTS.md.

The final Android build workflow requires a previous APK/AAB and validates the
actual artifact plus fresh-install and upgrade startup in a disposable emulator.
See [Android validation setup](tool/android/README.md).

The `doc/` folder includes design specifications as well as implementation notes;
forward-looking specifications are not user-facing feature promises.

[Support HMB development](https://github.com/sponsors/bsutton?o=esb).
