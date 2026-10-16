# Privacy and data flows

HMB stores its working database and local media on your device, but some features
send data to external services. This description is based on HMB main `51a4d8e6`
(version 0.42.0). It replaces the old blanket claim that data never leaves the
device. It does not establish a provider's retention or access policy.

## Local records and credentials

The local database contains your customer, contact, site, job and accounting
records. Photos and settings also use local application storage. On supported
Flutter platforms, integration credentials use the platform secure-storage
backend, separate from ordinary system configuration.

A database backup does not promise to restore device-held credentials. After a
restore, check integrations and sign-in before relying on them. Local storage and
secure credential storage do not establish that database backups are encrypted.

## Diagnostics when the app starts

The current app initializes Sentry diagnostics at startup. Its configuration
sets tracing and session/error replay sampling to 100%. This is separate from
the optional business integrations and is not gated by an integration setting
in the reviewed startup code. Backup worker code also reports errors to Sentry.

The source settings alone do not establish exactly which fields appear in events
or replays, which masking applies on each platform, who can access the service,
or how long data is retained. Those details require maintainer verification.

## Features that transfer data

| Feature | Data and trigger |
| --- | --- |
| Google Drive backup | Choosing Backup uploads a database archive to the signed-in Drive account. |
| Photo sync | Uploads photo files to Drive. Queued/unsynced photos may resume syncing at startup or resume when authentication is available; it is not limited to pressing Sync Photos each time. |
| Email | A message can include recipients, subject, body and attachments. Native-composer delivery opens the mail app; direct SMTP uses the configured mail service. Review the destination and attachments before sending. |
| Xero | Invoice upload can send customer/contact details and invoice lines, amounts and dates. Payment/credit status can be refreshed automatically on resume when the integration is enabled, as well as through Sync. |
| QuickBooks preview | Explicit invoice export sends the invoice snapshot and its customer reference to QuickBooks Online. |
| AI extraction and assistance | With an API key configured, invoking extraction/assistance can send selected text, job instructions or attachments to OpenAI. Receipt extraction sends the receipt image; customer extraction can send selected email text and attachments. Review what the action includes. |
| Google Maps | Geocoding, address validation and route planning can send addresses or coordinates to Google. Trip route lookup has a separate setting and needs a configured key. |
| Google Calendar | Configured synchronization writes schedule details such as job summary, notes, site address and times; navigation safety records can include destination/time. The sync setting defaults to enabled when absent, but supported authentication is also required. Review Settings → Integrations → Google Calendar. |
| Website booking requests | When enabled and configured, HMB fetches incoming requests, stores their contact/address/work details locally and acknowledges imports to the configured server. Rejection actions can send the request ID, reason and chosen delivery destination. |

## Location

Trip logging and trip route lookup start disabled in the database defaults.
When enabled, app-resume observations can record location and trip details.
GPS tracking requires its separate setting, an explicit start and the relevant
permissions. Location data is stored locally for trip records; optional route
lookups send origin/destination information to Google. Do not assume that all
location features are enabled by default or that all location stays on-device.

## Information still needed before publication

The maintainer needs to confirm diagnostics masking, retained fields, retention,
operator access and any consent controls, plus the applicable external-service
policies and device/OS backup behavior. No live accounts, messages, accounting
uploads or telemetry traffic were exercised for this review. See the technical
[evidence register](https://github.com/bsutton/hmb/blob/main/doc/manual-refresh/PRIVACY_EVIDENCE.md)
for source locations and open questions.
