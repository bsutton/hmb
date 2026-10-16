# HMB GitBook sync setup

Prepared against local and remote main `e55f79f22dfd412bd12b8657d46dfa470adf4e48`
on 2026-10-14. Documentation integration commit `1f17e1f7` is an ancestor.
The public manual is <https://hmb.onepub.dev/>. Brett's setup screen shows
GitHub selected at Connect/Authenticate. A later screenshot shows Pending and
Remove Git Sync, but still step 1 with Authenticate: this is not verified sync
success. Brett is handling the authentication popup/refresh himself.
The observed setup URL is
<https://app.gitbook.com/o/ecaaU3OrP2aDt9qZRymk/sites/site_W6ARh/structure/~/gitsync/setup>.
The earlier discovery report is historical.

## Intended connection

| Setting | Value |
| --- | --- |
| Repository | `bsutton/hmb` |
| Branch | `main`, after reviewed sync configuration reaches it |
| Project directory | `doc/manual-refresh` |
| Existing HMB space content mapping | `./` relative to project directory |
| Effective repository content directory | `doc/manual-refresh` |
| Space config | `doc/manual-refresh/.gitbook.yaml` |
| First page | `home.md` |
| Navigation | `SUMMARY.md` |
| Initial direction | GitHub → GitBook, subject to replacement confirmation |

These values target the current site-wide Git Sync UI. If the UI offers only
legacy space-level root configuration, inspect its fields before applying them.
Do not map the repository root: its README describes the Flutter project.

The explicit summary contains all 32 user pages in workflow order, excluding
historical audit/discovery reports. Privacy links to its technical evidence on
GitHub rather than importing that report as a manual page. All eight image
assets remain within the mapped directory.

Let GitBook generate its site mapping using the existing HMB space. Do not
invent a `gitbook-docs.yaml` space key: changing a live key can detach the
existing space and replace it with a new identity.

## Initial-sync checkpoint

Before clicking Sync, verify these reviewed files exist on the selected branch
and the mapped directory resolves to the manual. Preserve an export or recoverable
revision of current GitBook content and compare edits since the October 12 audit.
GitHub → GitBook replaces destination content and can affect the published site.
The opposite direction can overwrite revised Markdown with the old manual.

Privacy masking, retention and access questions remain outstanding. Sync setup
does not make that draft a complete privacy policy. Review before approving the
initial replacement.

Confirmation remains required for the concrete initial replacement/publication
and any new or broader persistent grant. Brett approved merging and pushing
these four configuration/documentation files to main. That approval does not
authorize initial content replacement. No authentication, grant or sync was
performed by this task. Brett is operating authentication himself; do not run
concurrent browser setup.

After sync, verify live home, navigation, images, existing page URLs and GitBook's
sync status/commit. Subsequent main commits and merged GitBook edits synchronize
bidirectionally; treat future docs merges as publication-capable changes.

## References and validation

- [Configuration](https://gitbook.com/docs/docs-as-code/git-sync/content-configuration)
- [Initial sync](https://gitbook.com/docs/docs-as-code/git-sync/enabling-github-sync)
- [Mapped directories](https://gitbook.com/docs/docs-as-code/git-sync/monorepos)

Run the existing `python3 tool/docs/validate_manual.py` for local references,
evidence paths and image hashes. This is not a GitBook import/build. Validate
the mapping and initial sync in GitBook after confirmation.

Read-only validation passed: 36 Markdown files, 78 local links, 30 evidence
paths and eight image hashes; `git diff --check` passed. Summary coverage is
32 unique user pages, with no local user-page links to the excluded reports.

CUA inventory on slayer4 returned no browsers/apps; opening the in-app browser
returned `Browser is not available: iab`. No browser was used to change settings.
No callable authenticated GitBook connector was available.
