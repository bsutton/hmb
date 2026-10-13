# GitBook source discovery

The public manual is <https://hmb.onepub.dev>. Its published metadata identifies
organisation `ecaaU3OrP2aDt9qZRymk`, space `220StKpP9uprvGvta4QY`, site
`site_W6ARh`, and revision `MYW5ag3XdF11hfOiU4Vq` in the retrieved snapshot.

Read-only discovery covered:

- The app repository's tracked tree and branches: no user manual SUMMARY.md or
  .gitbook.yaml. `doc/` holds developer notes/specifications.
- Nearby local repositories and remotes under `/home/bsutton/git`: matching HMB
  remotes are `bsutton/hmb` (app) and `bsutton/handyman` (separate project/server).
  No evidence connects either branch/root to this GitBook space.
- The authenticated GitHub repository inventory, including organisation repos:
  no separate HMB manual repository was identifiable by its name/description.
  This does not prove a private or differently named repository does not exist.
- Public GitBook HTML: `editOnGit` is undefined and revision `git` metadata is
  null. Only the app's issue/discussion links identify GitHub repositories.
  This is absence of public source evidence, not proof that Git Sync is disabled.
- Browser access to the official space: no in-app browser is available and the
  browser tool lists no connected browsers. There is no callable GitBook account
  connector in this execution environment.

No restricted API or hidden credential store was probed; no repository was
created to stand in for a presumed GitBook source. The app clone and review
worktree are explicitly local staging and are not presented as the docs repo.

## Exact remaining action

In the [official GitBook space](https://app.gitbook.com/o/ecaaU3OrP2aDt9qZRymk/s/220StKpP9uprvGvta4QY/),
the maintainer can read Git Sync settings and provide **repository URL, branch
and documentation root**, or confirm that **Git Sync is not configured**.
If the repository is not available to the existing connection, providing a local
checkout/export is sufficient for review; no publication or new permission is
needed for this task. Do not enable Git Sync merely to resolve this question.
