---
name: pr
description: Creates or updates a GitHub pull request via gh CLI with team-style title/body, issue/ticket links (Jira, Linear, Monday, GitHub Issues, etc.), optional code-review:request label when corporate-hosted, PR-template checklists filled from verifiable evidence, and screenshots saved under assets/pr-<n> then linked in the body. Use when the user wants a PR, pull request, gh pr create/edit, to update PR description or title, add screenshots to a PR, or provides a PR number or PR URL.
---

# GitHub PR create or update

## Route first (update vs new)

1. **PR from user message** — If the user gave a PR number or a GitHub PR URL (`…/pull/<n>` on `github.com` or enterprise hosts), use **update** with that number (parse `n` from URL).
2. **Else** — From repo root run `gh pr view --json number,headRefName,title` (no PR argument). If it succeeds, use **update** with returned `number`.
3. **Else** — `gh pr view` failed (no PR for current branch): use **new PR**.

**Update guard:** Before editing, confirm the PR’s head branch matches the current branch:

- `gh pr view <n> --json headRefName -q .headRefName`
- `git branch --show-current`

If they differ, stop and tell the user to checkout the correct branch or pass the right PR.

## Environment and git

- Run `gh` in a **non-sandboxed** terminal with **network** permission.
- If current branch is `main` or `master`, warn and do not proceed unless the user explicitly overrides.
- If there are uncommitted changes: remind the user; **never** stage or commit without explicit permission.
- Base diff for understanding changes: `git diff origin/<default>...HEAD` where `<default>` is from `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (fallback: `main`, then `master` if needed).

## Issue / Ticket tracking & Corporate mode

**Goal:** Pull requests can link to issues or tickets across trackers—such as Jira, Linear, Monday.com, Trello, or GitHub Issues. Drop-in support handles ticket IDs, issue keys, or direct task URLs provided by the user, branch name, or commit messages.

### Corporate mode switch (Jira / Tracker links + `code-review:request` label)

1. **Overrides (checked first):** `PR_SKIP_JIRA` set (any non-empty) → corporate mode **off** (skips ticket placeholders and label). `PR_REQUIRE_JIRA` set → corporate mode **on** on public `github.com` too.
2. **Otherwise:** From repo root run `gh repo view --json url -q .url`. Parse host (no path). Corporate mode **off** if host is exactly one of: `github.com`, `gist.github.com`, `gitlab.com`, `codeberg.org`, `bitbucket.org`, `dev.azure.com`, `ssh.dev.azure.com`. Corporate mode **on** for any other host (enterprise GitHub, self-hosted GitLab, etc.).
3. If `gh repo view` fails, default corporate mode **off**.

### Extracting & linking tickets or issues

Support any issue tracker (Jira, Linear, Monday, Trello, GitHub Issues, etc.):

1. **User input or URLs:** If the user provided an issue URL (e.g. Linear `https://linear.app/.../issue/ENG-123`, Monday `https://*.monday.com/boards/.../pulses/12345`, Jira `https://jira.domain.com/browse/PROJ-123`, Trello card, or GitHub Issue URL), link it directly in the PR body.
2. **Ticket Keys / IDs:**
   - Look for issue keys in user text, branch name, or recent commits (e.g., Jira `PROJ-123`, Linear `ENG-456`, GitHub `#123`, or Monday item ID).
   - When a ticket key or URL is present, include it in the PR body (and title prefix if team convention uses `<KEY>: summary`).
3. **Corporate mode fallback:**
   - When corporate mode is **on** and no ticket/issue reference was found, use a key placeholder like `PROJ-123` in the title/body or prompt the user for the ticket ID.
   - On `gh pr create` in corporate mode, pass `--label "code-review:request"` if supported by the repository.

### When corporate mode is **off** (OSS / standard repos)

- **Title (for PR):** conventional-commit-style summary (e.g., `feat(scope): add thing`).
- If an issue key or URL was explicitly provided by the user, add a single link or reference line in the PR body.
- Do **not** pass `--label "code-review:request"` on create unless requested.

## Title and body

- **Title (with ticket key):** `<KEY>: <summary>` (e.g., `PROJ-123: feat(auth) add sso login` or `ENG-456: fix(api) handle timeout` — omit the second colon after type/scope so there is no double `:` in the title).
- **Title (without ticket key):** `<conventional-commit-style summary>` (e.g., `feat(auth): add sso login`).
- **Body:** Reviewer-focused outcomes — what changed, what files/areas, behavior added/changed/removed, and linked issue/ticket URL. Avoid internal commit-by-commit narrative unless relevant. Short bullets.
- **Regenerate** the full body from scratch each time unless the user explicitly asks to preserve or append to the existing description.

## Template

- Search for `PULL_REQUEST_TEMPLATE.md` under `.github/`, `docs/`, and `.gitlab/` (repo root and common layouts).
- **If found:** Structure the body to match the template sections and headings.
- **If missing:** Minimal body: Context, Changes, Related Issue/Ticket.

## Checklists in the template

When the template contains `- [ ]` / `- [x]` items:

- After filling narrative sections, set items to `- [x]` only when **clearly supported** by available evidence (diff, touched paths, user-stated facts like “tests passed”, obvious mechanical checks).
- Leave `- [ ]` when unsure. **Do not** check boxes to imply testing, security review, or release steps without evidence.
- Optionally add one short line if many items stay unchecked, e.g. that they were not verified from the diff alone.

## Screenshots for PR descriptions

When the user asks to add screenshots to a PR (or the template has a Screenshots section and captures are needed):

### Where to save

Save screenshots in an `assets/` folder in the rules/docs repository (or repo-configured asset folder):

```text
assets/pr-<n>/<descriptive-kebab-name>.png
```

Example: `assets/pr-1166/dashboard-dark-mode.png`

Create `assets/pr-<n>/` if missing. Prefer PNG. Use short kebab filenames that describe what the screenshot displays.

### Commit, push, and link

1. Commit and push images to the assets repository when requested to attach PR screenshots.
2. In the PR body Screenshots section, embed with markdown images using raw image URLs and fallback blob links:

```markdown
![Short label](https://<github-host>/<owner>/<repo>/raw/main/assets/pr-<n>/<file>.png)

[file.png](https://<github-host>/<owner>/<repo>/blob/main/assets/pr-<n>/<file>.png)
```

3. Include a brief note under Screenshots explaining what state or environment the capture shows.

**Quality bar:** Only include screenshots that show the feature or fix under review. Avoid skeleton loaders, truncated views, or irrelevant popups.

## Write body and run gh

1. Compose the full markdown body (including filled template and checklists).
2. **Write** it to a temp file at the repo root, e.g. `.pr-body-temp.md`, using the editor tool (avoids shell quoting issues with backticks and special characters).
3. **Create:** `gh pr create --title "<title>" --body-file .pr-body-temp.md`
   If corporate mode is **on**, append ` --label "code-review:request"`.
4. **Update:** `gh pr edit <n> --title "<title>" --body-file .pr-body-temp.md`
5. **Always delete** `.pr-body-temp.md` when done — last step every run, success or failure (early stop included). Use the Delete tool or `rm -f .pr-body-temp.md` from repo root. Never leave the temp file behind.

## Troubleshooting

- **`gh` not found or auth errors:** Tell the user to install GitHub CLI and run `gh auth login` (and `gh auth refresh` if needed).
- **Wrong repo:** Run commands from the git root of the project that should host the PR.
- **Ambiguous PR number:** If multiple remotes or contexts confuse `gh`, use `gh pr view <n> --repo owner/name` when the user specifies the repo.

## Quick command reference

```bash
# Current branch’s PR (JSON)
gh pr view --json number,headRefName,title

# PR head branch vs local
gh pr view <n> --json headRefName -q .headRefName
git branch --show-current

# Default branch name
gh repo view --json defaultBranchRef -q .defaultBranchRef.name
```
