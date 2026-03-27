@AGENTS.md

## Claude-Specific Context

### Skills Available
Skills in `.claude/skills/`:
- `hmb-flutter-dev` — Flutter/Dart development, architecture, build commands
- `hmb-security-audit` — Security findings, audit checklist, hardening
- `hmb-k3s-testing` — K3s + AWS deployment, Dockerfile, manifests

### Project Plan
Comprehensive 8-phase plan at `docs/project-plan.md`.

### Operating Rules
- **Public repo** — never commit secrets, keystores, credentials, or customer PII
- **Branch protection** — all changes via PR, CODEOWNER review required
- **Secrets via `--dart-define`** — use `AppConfig` class in `lib/util/config/app_config.dart`
- **Container builds** — amd64-only, `--provenance=false`
- **K8s deploy** — manifests in `kubernetes/`, `Recreate` strategy, `harbor-pull-secret`
- **Service selector** — must include `app.kubernetes.io/component: web`
- **Coding style** — 2-space indent, 80-char lines, `dart format .` + `flutter analyze` before commit

### Key Architecture Decisions
- CupertinoApp (Apple design) over Material — see `docs/project-plan.md`
- Migrating state management to Riverpod (from June/Provider/setState)
- Service layer between UI and DAOs (fix god-class DAOs)
- Multi-AI provider abstraction (`AIProvider` interface)
- Offline-first with sync engine (Phase 7)
- Dual hosting: k3s primary, AWS serverless optional

### Private Dependencies
`booking_request` and `calendar_view` are on `onepub.dev` — must be forked or vendored before CI builds work.

### Reference
| What | Where |
|------|-------|
| Project plan (8 phases) | `docs/project-plan.md` |
| Security findings | `.claude/skills/hmb-security-audit.md` |
| K8s manifests | `kubernetes/hmb.yaml` |
| CI workflow | `.github/workflows/ci.yml` |
| Runtime config | `lib/util/config/app_config.dart` |
| Backup encryption | `lib/database/management/backup_providers/backup_encryption.dart` |
| DB migrations | `assets/sql/upgrade_scripts/` (164 scripts) |
