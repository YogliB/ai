# GitHub

Extract: PR and issue numbers (`#123`, `owner/repo#123`), GitHub URLs (pull, issues, commits, compare), and keys embedded in the branch name.

Resolve with `gh`:

- PR under review: `gh pr view <n|url> --json title,body,headRefName,commits`
- Issue: `gh issue view <n|url> --repo <owner/repo> --json title,body,labels`. A bare `#123` belongs to the repository of the source that linked it; never resolve it against the current checkout unless that is where it was found.
- Commit messages: `git log --format='%s%n%b' <base>...<head>`

Follow: linked issues and PRs in bodies (`fixes #123`, URLs) with the same commands, one level at a time.

Without `gh` (or without access through it), try connected GitHub tools or web fetch first; record `not opened (no tool)` only when none of them can read it. Never reconstruct a ticket's contents from its URL.
