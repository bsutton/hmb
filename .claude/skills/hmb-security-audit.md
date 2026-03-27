# HMB Security Audit

Security review and hardening skill for the HMB app. Use when auditing code for vulnerabilities, reviewing auth flows, hardening data handling, or preparing for production deployment.

## Known Findings (Baseline 2026-03-27)

### HIGH Severity

1. **Unencrypted Backups** — Backup zip files (DB + photos) uploaded to Google Drive without local encryption. If intercepted or the Drive account is compromised, all customer data is exposed.
   - File: `lib/database/management/backup_providers/zip_isolate.dart`
   - Fix: Add AES-256 encryption before upload (consider `encrypt` or `cryptography` package)

### MEDIUM Severity

2. **OAuth Missing PKCE** — Xero OAuth uses AuthorizationCodeGrant without PKCE. Author has a TODO to migrate.
   - File: `lib/api/xero/xero_auth.dart` (lines 221-225)
   - File: `lib/api/chat_gpt/chat_gpt_auth_service.dart` (line 72 claims PKCE but doesn't implement it)
   - Fix: Add code_challenge/code_verifier to OAuth grants

3. **No Input Length Validation** — User input fields lack explicit length limits. Could cause issues with oversized data in SQLite or PDF generation.
   - Fix: Add maxLength to TextFormField widgets and validate in DAOs

4. **ChatGPT Client ID Placeholder** — `const _clientId = 'YOUR_CLIENT_ID';` is a placeholder, not functional.
   - File: `lib/api/chat_gpt/chat_gpt_auth_service.dart` (line 26)

### LOW Severity

5. **Hardcoded Sentry DSN** — Public DSN in source code. Verify Sentry project is org-restricted.
   - Files: `lib/main.dart`, `zip_isolate.dart`, `google_drive_backup_provider.dart`

6. **Beta Dependency** — `flutter_secure_storage: ^10.0.0-beta.4` — upgrade when stable.

7. **No OAuth State Parameter Validation** — Redirect handlers don't validate the `state` parameter, making CSRF possible on OAuth flows.
   - Files: `lib/api/xero/local_server_redirect_handler.dart`, `lib/api/oauth/local_server_redirect_handler.dart`

## What's Good

- **SQL injection**: All queries use parameterized `whereArgs` — no string interpolation in SQL
- **File sanitization**: `_safe()` in `hmb_image_cache.dart` strips unsafe chars from filenames
- **Localhost-only OAuth redirects**: Redirect servers bind to `InternetAddress.loopbackIPv4`
- **HTTPS everywhere**: All external API calls use HTTPS
- **No eval/dynamic code execution**: No unsafe reflection on user input
- **Credential storage**: API keys and OAuth tokens stored in SQLite/secure_storage, not hardcoded

## Audit Checklist

When reviewing new code or preparing for deployment:

- [ ] All SQL queries use parameterized arguments (no string interpolation)
- [ ] User input validated (length, format, sanitization) before storage
- [ ] No hardcoded API keys, tokens, or secrets
- [ ] OAuth flows implement PKCE
- [ ] File paths sanitized before filesystem operations
- [ ] Backup data encrypted before cloud upload
- [ ] HTTPS used for all external communication
- [ ] Sentry DSN is org-restricted
- [ ] Dependencies audited (`flutter pub outdated`, `flutter pub pub-audit`)
- [ ] No customer PII in test fixtures or assets
- [ ] Signing keys not committed to repo

## Security-Sensitive Paths

| Area | Path | Risk |
|------|------|------|
| OAuth credentials | `lib/api/xero/xero_auth.dart` | Token storage, PKCE gap |
| ChatGPT auth | `lib/api/chat_gpt/chat_gpt_auth_service.dart` | API key handling |
| Google Drive auth | `lib/database/management/backup_providers/google_drive/` | Token persistence |
| Backup creation | `lib/database/management/backup_providers/zip_isolate.dart` | Unencrypted data |
| DB migrations | `assets/sql/upgrade_scripts/` | Schema integrity |
| Secure storage | Uses `flutter_secure_storage` (beta) | Platform keychain |
| Signing keys | `hmb-production.keystore*`, `hmb-debug.keystore*` | Must stay private |

## Running Security Checks

```bash
# Dependency audit
flutter pub outdated
flutter pub deps --no-dev | grep -i "security\|vulnerability"

# Static analysis (lint_hard rules)
flutter analyze

# Search for hardcoded secrets
grep -rn "api_key\|secret\|password\|token" lib/ --include="*.dart" | grep -v "test\|mock\|TODO\|//"

# Check for HTTP (non-TLS) endpoints
grep -rn "http://" lib/ --include="*.dart" | grep -v "localhost\|127.0.0.1\|//"
```
