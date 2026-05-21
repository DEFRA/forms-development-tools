# Dependency Management — Manual Runbook

Use this runbook to detect and remove unused dependencies, update to the latest
available versions, and open PRs — one repo at a time.

All scripts live in `skills/dependency-management/scripts/`. Run them from `forms-development-tools/`.

---

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`)
- `git` configured with access to the target repo's remote
- Node.js available (scripts use `npx` for zero-install tooling)

---

## Workflow

Replace `<repo>` with the absolute path to the target microservice.

### Step 1 — Preflight

```bash
./skills/dependency-management/scripts/01-preflight.sh <repo>
```

Creates branch `chore/dependency-management-<YYYY-MM-DD>` from `origin/main`.
**Save the branch name from the output** — you'll need it for stacked PRs.

Fails if the repo has uncommitted changes. Stash or commit before proceeding.

### Step 2 — Detect unused dependencies

```bash
./skills/dependency-management/scripts/02-detect-unused.sh <repo>
```

Review the output. For each flagged dependency, check whether it is genuinely
unused or a false positive (e.g. dynamically required, loaded by a framework
plugin, or referenced only in config files). Remove confirmed unused deps from
`package.json`, then run `npm install` in `<repo>`.

### Step 3 — Verify removals

```bash
./skills/dependency-management/scripts/04-verify.sh <repo>
```

If it fails, restore the dep that caused the failure and re-verify.
Once passing, commit:

```bash
git -C <repo> add package.json package-lock.json
git -C <repo> commit -m "chore: remove unused dependencies"
```

### Step 4 — Detect available updates

```bash
./skills/dependency-management/scripts/03-update-deps.sh <repo>
```

Review the output. Classify each major update (`isMajor: true`) as:
- **Simple** — mechanical change only (renamed import, moved export). Apply now.
- **Medium** — bounded code changes. Apply in a stacked PR (see below).
- **Large** — architectural decisions required. Defer and document.

Apply minor/patch updates and any simple major updates to `package.json`, then
run `npm install` in `<repo>`.

### Step 5 — Verify updates

```bash
./skills/dependency-management/scripts/04-verify.sh <repo>
```

If a specific update caused a failure, pin it at its previous version in
`package.json`, re-run `npm install`, and re-verify. Repeat until clean.

```bash
git -C <repo> add package.json package-lock.json
git -C <repo> commit -m "chore: update dependencies to latest minor/patch"
```

Add one commit per simple major applied:

```bash
git -C <repo> commit -m "chore: upgrade <package> to vN"
```

### Step 6 — Handle medium major updates (stacked PRs)

For each medium major, create a stacked branch from the baseline:

```bash
BASELINE="chore/dependency-management-2026-05-21"   # from Step 1 output
PACKAGE="express"

./skills/dependency-management/scripts/01-preflight.sh <repo> \
  --base "$BASELINE" \
  --branch "${BASELINE}-${PACKAGE}"
```

Apply the update, make required code changes, run `npm install`, verify:

```bash
./skills/dependency-management/scripts/04-verify.sh <repo>
```

Commit, then write a PR description and verify with `--dry-run` before creating:

```bash
./skills/dependency-management/scripts/05-create-pr.sh <repo> /tmp/pr-express.md \
  --base "$BASELINE" --dry-run

./skills/dependency-management/scripts/05-create-pr.sh <repo> /tmp/pr-express.md \
  --base "$BASELINE"
```

Repeat for each medium major, always using `--base "$BASELINE"` so branches
are independent of each other.

Switch back to the baseline branch before writing the baseline PR:

```bash
git -C <repo> checkout "$BASELINE"
```

### Step 7 — Create the baseline PR

Write a markdown file describing the changes (e.g. `/tmp/pr-baseline.md`):

```markdown
## Dependency management

### Removed (unused)
- `lodash` — not imported anywhere in source

### Updated (minor/patch)
- `express`: 4.18.0 → 4.19.2

### Major updates — applied (simple)
- `some-package`: 2.x → 3.x — only required renaming one import

### Major updates — stacked PRs
- `express`: #123

### Major updates — deferred
- `webpack`: 4.x → 5.x — requires config rewrite; significant effort
```

Verify first, then create:

```bash
./skills/dependency-management/scripts/05-create-pr.sh <repo> /tmp/pr-baseline.md --dry-run

./skills/dependency-management/scripts/05-create-pr.sh <repo> /tmp/pr-baseline.md
```

---

## Resuming on a later day

Do not re-run Step 1. The branch already exists. Find its name:

```bash
git -C <repo> branch --show-current
```

Continue from wherever you left off.
