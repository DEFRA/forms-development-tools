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
**Save the branch name from the output** — you'll need it throughout the workflow.

Fails if the repo has uncommitted changes. Stash or commit before proceeding.

### Step 2 — Detect unused dependencies

```bash
./skills/dependency-management/scripts/02-detect-unused.sh <repo>
```

For each flagged dependency, verify it is genuinely unused before removing it.
Common false positives:

- `@types/*` packages — keep unless the package itself is also being removed
- Packages referenced only in config files knip doesn't scan (e.g. `jest.config.*`, `babel.config.*`)
- Peer dependencies pulled in transitively at runtime
- **String-referenced packages** — pino transports, hapi plugins registered by name, and
  webpack loaders are loaded via string at runtime; knip cannot detect these. Search broadly:
  ```bash
  grep -r "'<package-name>'\|\"<package-name>\"" <repo> \
    --include="*.ts" --include="*.js" --include="*.mjs" --include="*.cjs" \
    --exclude-dir=node_modules --exclude-dir=.git
  ```

Remove confirmed unused deps:

```bash
npm --prefix <repo> uninstall <dep1> <dep2> ...
```

**If nothing was flagged, skip to Step 4.**

### Step 3 — Verify removals

```bash
./skills/dependency-management/scripts/04-verify.sh <repo>
```

If it fails, restore the dep that caused the failure and re-verify:

```bash
npm --prefix <repo> install <dep>
```

If multiple deps were removed and the failure is ambiguous, binary search: restore half,
re-verify, narrow down to the offender. Repeat until clean.

Once passing, commit — use `add -A` to capture any source file fixes made during the loop:

```bash
git -C <repo> add -A
git -C <repo> commit -m "chore: remove unused dependencies"
```

### Step 4 — Detect and classify all available updates

```bash
./skills/dependency-management/scripts/03-update-deps.sh <repo>
```

**If no updates are shown, skip Steps 5 and 6 and go straight to Step 7.**

Classify every update before applying any:

- Minor/patch (`isMajor: false`) — all go into the baseline branch
- Major (`isMajor: true`) — classify each individually:

**Classification criteria — base this on implementation effort, not semantic version number:**
- **Simple** — apply in the baseline branch. Covers:
  - No code changes needed at all, OR
  - A small number of trivial code changes (rename an import, swap a class name,
    update a config key, add a cast). The kind of fix a developer does in under 10
    minutes without reading docs. Skipping major versions does NOT automatically make
    something medium — check what actually changed in the code you use.
- **Medium** — gets its own stacked branch and PR. Covers:
  - A moderate amount of bounded, straightforward changes across multiple files.
    For example: a new required option everywhere an API is called, a changed method
    signature used in several places, a config format that needs rewriting.
- **Large** — defer and document. Covers:
  - Significant rethinking, architectural decisions, or evaluation of alternatives.
    For example: a framework that changes its rendering model, a validator that
    changes its schema DSL, a linter that renames half its rule set.

To read a changelog:

```bash
npx --yes changelog <package-name>
```

To check codebase usage of a package:

```bash
grep -r "from '<package-name>\|require('<package-name>" <repo> \
  --include="*.ts" --include="*.js" --include="*.mjs" --include="*.cjs" -l \
  --exclude-dir=node_modules --exclude-dir=.git
```

**Write down the three lists before proceeding:**

- Simple majors: (or none)
- Medium majors: (or none — each will get a stacked branch and PR)
- Large majors: (or none — will be deferred and documented)

### Step 5 — Apply minor/patch and simple major updates

Apply all minor/patch updates in one command:

```bash
npm --prefix <repo> install dep1@^x.y.z dep2@^x.y.z ...
./skills/dependency-management/scripts/04-verify.sh <repo>
```

If verify fails, binary search to find the offending package and pin it at its previous version:

```bash
npm --prefix <repo> install <offending-dep>@<previous-version>
```

Re-verify. Repeat until clean. Note any pinned packages for the PR body.

```bash
git -C <repo> add -A
git -C <repo> commit -m "chore: update dependencies to latest minor/patch"
```

Then apply each simple major **one at a time**, verifying after each:

```bash
npm --prefix <repo> install <package>@<new-version>
./skills/dependency-management/scripts/04-verify.sh <repo>
```

If verify fails:
- If the fix is trivial (rename an import, update a config key, add a type cast,
  adjust a single call site) — make the fix, re-verify, then commit with `add -A`.
- If fixing requires more than trivial effort — **reclassify it as Medium**:
  revert the install and add it to the medium list.
  ```bash
  npm --prefix <repo> install <package>@<previous-version>
  ```

Once verify passes, commit each simple major separately:

```bash
git -C <repo> add -A
git -C <repo> commit -m "chore: upgrade <package> to v<N>"
```

### Step 6 — Handle medium major updates (stacked PRs)

**If the medium list is empty, skip to Step 7.**

Keep a running list of stacked PR URLs — you will need them all for Step 7.

For each medium major, work through 6a–6d:

**6a. Create a stacked branch from the baseline:**

```bash
BASELINE="chore/dependency-management-<YYYY-MM-DD>"  # from Step 1

./skills/dependency-management/scripts/01-preflight.sh <repo> \
  --base "$BASELINE" \
  --branch "${BASELINE}-<package-name>"
```

**6b. Apply the update, fix any breakage, and verify:**

```bash
npm --prefix <repo> install <package>@<new-version>
# make any required source code changes
./skills/dependency-management/scripts/04-verify.sh <repo>
```

If verify fails: investigate, fix source code, re-run verify. Repeat until passing.

If the fix turns out to be too complex (architectural, not just code changes), reclassify
as Large: check out the baseline, note the deferral reason, move to the next medium major.

```bash
git -C <repo> checkout "$BASELINE"
```

**6c. Commit and open the stacked PR:**

```bash
git -C <repo> add -A
git -C <repo> commit -m "chore: upgrade <package> to v<N>"
```

Write `/tmp/pr-<repo-name>-<package>.md`:

```markdown
## Upgrade <package> to v<N>

**Why this is medium, not large:** <reason>

**What changed in the package:**
- <breaking change from changelog>

**What changed in the codebase:**
- <files modified and why>

**Merge order:** merge the baseline PR first, then this one.
```

Preview and create the PR (targets `$BASELINE`, not `main`):

```bash
./skills/dependency-management/scripts/05-create-pr.sh <repo> /tmp/pr-<repo-name>-<package>.md \
  --base "$BASELINE" --dry-run

./skills/dependency-management/scripts/05-create-pr.sh <repo> /tmp/pr-<repo-name>-<package>.md \
  --base "$BASELINE"
```

Note the PR URL — you need it for Step 7.

**6d. Return to the baseline branch before the next medium major:**

```bash
git -C <repo> checkout "$BASELINE"
```

Repeat 6a–6d for every medium major.

### Step 7 — Create the baseline PR

**Only open this after Step 6 is fully complete.**

Write `/tmp/pr-<repo-name>-baseline.md`:

```markdown
## Dependency management

### Removed (unused)
- `lodash` — not imported anywhere in source

### Updated (minor/patch)
- `express`: 4.18.0 → 4.19.2

### Major updates — applied (simple, in this PR)
- `some-package`: 2.x → 3.x — only required renaming one import

### Major updates — stacked PRs
<!-- These PRs target this branch, not main. Merge this PR first,
     then merge each stacked PR after it lands on main. -->
- `express`: <PR URL>

### Major updates — deferred (large)
- `webpack`: 4.x → 5.x — requires config rewrite; significant effort
```

Verify first, then create:

```bash
./skills/dependency-management/scripts/05-create-pr.sh <repo> /tmp/pr-<repo-name>-baseline.md --dry-run

./skills/dependency-management/scripts/05-create-pr.sh <repo> /tmp/pr-<repo-name>-baseline.md
```

Note the baseline PR URL and share all URLs:

```
Baseline PR: <URL>
Stacked PRs (merge after baseline lands on main):
  <package>: <URL>
  ...
```

---

## Resuming on a later day

Do not re-run Step 1. The branch already exists. Find its name:

```bash
git -C <repo> branch --show-current
```

Verify it starts with `chore/dependency-management-` before continuing.
Continue from wherever you left off.
