# Privacy evidence register

Technical source audit of main `51a4d8e6846fedde31955cbdcc9c484ed44b5138`.
Paths below are relative to the HMB repository root. These observations are not
claims about actual historical customer transmissions or provider legal terms.

| Flow | Source evidence | Trigger/default and limits |
| --- | --- | --- |
| Sentry startup | `lib/main.dart:56` (`runHmbApp`, lines 62–75) | Initialization unconditional; tracing, session replay and error replay rates 1.0. Desktop native support differs. Debug only disables frame tracking. No consent gate/scrubbing hooks in these options. |
| Worker diagnostics | `lib/database/management/backup_providers/zip_isolate.dart:87`; `lib/database/management/backup_providers/google_drive/background_backup/google_drive_backup_provider.dart:212` | Worker initialization and exception reporting exist independently. Inspect SDK masking and worker payloads before any “no data access” assurance. |
| Database | `lib/database/management/backup_providers/backup_provider.dart:75`; `lib/database/management/backup_providers/db_path.dart:4`; `lib/database/management/database_helper.dart:65` | Application documents `handyman.db`; local location does not prove OS backup exclusion or database encryption. |
| Secrets | `lib/dao/dao_system.dart:48`; `lib/dao/system_secret_backend_flutter.dart:14`; `lib/dao/system_secret_store.dart:25` | Immutable ordinary config excludes integration secrets; Flutter backend uses FlutterSecureStorage. Covers accounting, AI, Maps, ihserver and SMTP credential types. Platform stub is a distinct implementation. |
| Photo files | `lib/ui/widgets/media/captured_photo.dart`; `lib/ui/widgets/media/photo_controller.dart:191`; `lib/cache/hmb_image_cache.dart` | Captured files copied to app storage/cache; camera/gallery picker behavior depends on platform. No claim of database-only storage. |
| Archive backup | `lib/database/management/backup_providers/backup_provider.dart:73`; `lib/database/management/backup_providers/zip_isolate.dart:95` | Copies and zips DB before provider.store. Ordinary ZipFileEncoder shown; no archive encryption established. Photo sync is separate. |
| Drive upload | `lib/database/management/backup_providers/google_drive/background_backup/google_drive_backup_provider.dart:130`; `upload_photos_in_backup.dart:125` in the same directory | Backup ZIP and photo bytes go to Google Drive. Backup sign-in explicitly manual in store flow. |
| Resumed photo sync | `lib/main.dart:194`; `lib/database/management/backup_providers/google_drive/background_backup/photo_sync_service.dart:128` | Startup/resume calls sync; eligible queued photos and usable auth required. Not every transfer requires a new button press. |
| Native vs SMTP email | `lib/ui/dialog/hmb_email_sender.dart:48`; `lib/database/management/backup_providers/email/email_backup.dart:105` | Native composer opens app; direct send creates SMTP message with from/to/cc/bcc, subject, body and attachments. SMTP and Gmail OAuth routes differ. |
| Receipt AI | `lib/api/chat_gpt/receipt_api_client.dart:65` | Configured key + invocation; base64 image to OpenAI chat completions, extraction prompt includes supplier/date/totals/tax/line details. |
| Customer AI | `lib/api/chat_gpt/customer_extract_api_client.dart:93` | Selected email text plus eligible attachments (per-file size cap) to OpenAI responses; names, contact/address/job-party extraction. |
| Job AI | `lib/api/chat_gpt/job_assist_api_client.dart:57` | Description/instructions/summary/existing tasks and relevant attachments depending on action. |
| Xero | `lib/api/accounting/xero_accounting_adaptor.dart:54`; `lib/api/xero/models/xero_contact.dart:32`; `lib/api/xero/models/xero_invoice.dart:38` | Explicit invoice/contact upload; contact name/email/phone, invoice contact/reference/lines/dates. |
| Xero resume | `lib/main.dart:178`; `lib/api/xero/xero_invoice_payment_sync_service.dart:55` | Refresh on resume when enabled; remote payment/credit import. |
| QuickBooks | `lib/api/accounting/quickbooks_invoice_client.dart:31` | Explicit preview export; customer ref/currency/number/dates/line description/amount/tax/item codes. |
| Calendar | `lib/integrations/google_calendar/google_calendar_sync.dart:47`, `:65`, `:210`; `lib/util/dart/app_settings.dart:35`, `:57` | Default sync setting true when unset; supported auth required. Schedule job summary/notes/site/times; safety record destination/time. |
| Trip capture | `lib/api/trip_capture_service.dart:155`, `:294`, `:330`; `assets/sql/upgrade_scripts/v219.sql`; `v223.sql` | Logging, lookup and GPS defaults disabled. Resume observation gated; explicit GPS start checks settings/permissions; optional Google route lookup sends coordinates/addresses. |
| Mailing maps | `lib/ui/tools/mailings/google_maps_route_service.dart:160`, `:1075`, `:1169` | Requested validation/geocoding/optimization transfers origin and recipient address/route data. |
| Booking import | `lib/api/ihserver/booking_request_sync_service.dart:17`; `lib/api/ihserver/ihserver_api_client.dart:75`; `lib/main.dart:167` | Enabled/configured resume sync, hourly throttle; fetch and local store, acknowledgment of IDs; explicit rejection sends reason/delivery destination. |

Before publishing a privacy policy, the owner must settle: exact Sentry fields
and replay masking by platform; event/backup retention and deletion; operator
access; user notice/consent; OS/cloud backup exclusions; external service policies.
This task did not connect to those services or capture production network traffic.
