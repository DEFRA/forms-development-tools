---
name: dependency-management
description: Use when performing a dependency sweep on a forms-* Node.js microservice — one repo at a time.
disable-model-invocation: true
allowed-tools: Bash
argument-hint: [repo-path]
---

# Dependency Management Skill

## When to use

When a developer wants to run a dependency sweep on one of the forms-* microservices.
One repo at a time.

## Setup

Scripts are bundled with this skill. Set `SCRIPTS` and resolve the repo path from
`$ARGUMENTS` before doing anything else:

```bash
SCRIPTS="${CLAUDE_SKILL_DIR}/scripts"

# Resolve repo path — $ARGUMENTS may be a name (e.g. "forms-runner") or an absolute path.
# A bare name is resolved relative to the current working directory.
REPO_NAME="$ARGUMENTS"
if [[ "$REPO_NAME" == /* ]]; then
  REPO="$REPO_NAME"
else
  REPO="$(pwd)/$REPO_NAME"
fi
```

Confirm the directory exists before proceeding. If it does not, report the error and stop.

## Step 1 — Preflight

```bash
OUT=$("$SCRIPTS/01-preflight.sh" "$REPO" --format json)
```

Check `status` in output. If `error`, report to the user and stop — the repo
has uncommitted changes that must be resolved first.

If `ready`, store the branch name:

```bash
BASELINE=$(OUT="$OUT" node -p "JSON.parse(process.env.OUT).branch")
```

**If resuming on a later day:** read the branch from git instead of re-running preflight:

```bash
BASELINE=$(git -C "$REPO" branch --show-current)
```

Verify `$BASELINE` starts with `chore/dependency-management-` before continuing.

## Step 2 — Detect unused dependencies

```bash
OUT=$("$SCRIPTS/02-detect-unused.sh" "$REPO" --format json)
UNUSED_DEPS=$(OUT="$OUT" node -p "JSON.parse(process.env.OUT).unusedDependencies")
UNUSED_DEV=$(OUT="$OUT" node -p "JSON.parse(process.env.OUT).unusedDevDependencies")
```

**If both arrays are empty, skip to Step 4.**

For each flagged dependency, examine the codebase to confirm it is genuinely
unused before removing it. Common false positives:

- `@types/*` packages — keep unless the package itself is also being removed
- Packages loaded in config files not scanned by knip (e.g. `jest.config.*`, `babel.config.*`, `webpack.config.*`)
- Peer dependencies pulled in transitively by other packages at runtime
- **String-referenced packages** — pino transports, hapi plugins registered by name, and
  webpack loaders load packages via string at runtime; knip cannot detect these.
  Search broadly — not just `src/`:
  ```bash
  grep -r "'<package-name>'\|\"<package-name>\"" "$REPO" \
    --include="*.ts" --include="*.js" --include="*.mjs" --include="*.cjs" \
    --exclude-dir=node_modules --exclude-dir=.git
  ```

Remove only confirmed unused deps:

```bash
npm --prefix "$REPO" uninstall <dep1> <dep2> ...
```

## Step 3 — Verify removals

**Skip this step if nothing was removed in Step 2.**

```bash
OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)
STATUS=$(node -p "JSON.parse('$OUT').status")
```

If `failed`: read `step` and `error` from output. Identify which removed dep caused
the failure. Restore it and re-verify:

```bash
npm --prefix "$REPO" install <dep>
```

If multiple deps were removed and the failure is ambiguous, binary search: restore half,
re-verify, narrow down to the offender.

Repeat until `passed`, then commit — use `add -A` to capture any source file fixes
made during the verify/fix loop:

```bash
git -C "$REPO" add -A
git -C "$REPO" commit -m "chore: remove unused dependencies"
```

## Step 4 — Detect and classify all available updates

```bash
OUT=$("$SCRIPTS/03-update-deps.sh" "$REPO" --format json)
```

**If the updates object is empty, skip Steps 5 and 6 and go straight to Step 7.**

Classify every update before applying any of them:

- Minor/patch (`isMajor: false`) — all go into the baseline branch
- Major (`isMajor: true`) — classify each individually:

**Classification criteria — base this on implementation effort, not semantic version number:**
- **Simple** — goes into the baseline branch. Covers:
  - No code changes needed at all, OR
  - A small number of trivial code changes (rename an import, swap a class name,
    update a config key, add a cast). The kind of changes a developer fixes in
    under 10 minutes without reading docs. Skipping major versions does NOT
    automatically make something medium — check what actually changed in the code we use.
- **Medium** — gets its own stacked branch and PR. Covers:
  - A moderate amount of bounded, straightforward changes across multiple files.
    For example: a new required option everywhere an API is called, a changed
    method signature used in several places, a config format that needs rewriting.
    The work is clear and finite, but not trivial.
- **Large** — deferred and documented. Covers:
  - Significant rethinking, architectural decisions, or evaluation of alternatives.
    For example: a framework that changes its rendering model, a validator that
    changes its schema DSL, a linter that renames half its rule set.

To read a changelog:

```bash
npx --yes changelog <package-name>
```

To check codebase usage of a package:

```bash
grep -rE "from ['\"]<package-name>['\"]|require\(['\"]<package-name>" "$REPO" \
  --include="*.ts" --include="*.js" --include="*.mjs" --include="*.cjs" -l \
  --exclude-dir=node_modules --exclude-dir=.git
```

**After classifying, show the user the three lists and wait for confirmation before
proceeding:**

- Simple majors: `[list]` (or none)
- Medium majors: `[list]` (or none — if any exist, each gets a stacked branch and PR)
- Large majors: `[list]` (or none — will be deferred and documented)

Do not proceed until the user confirms or adjusts the classification.

## Step 5 — Apply minor/patch and simple major updates (baseline branch)

You are on `$BASELINE` throughout this step.

Apply all minor/patch updates in one npm command:

```bash
npm --prefix "$REPO" install dep1@^x.y.z dep2@^x.y.z ...
OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)
```

If `failed`: binary search to find the offending update. Pin it at its previous version:

```bash
npm --prefix "$REPO" install <offending-dep>@<previous-version>
```

Re-verify. Repeat until `passed`. Note any pinned packages for the PR body.

Commit:

```bash
git -C "$REPO" add -A
git -C "$REPO" commit -m "chore: update dependencies to latest minor/patch"
```

Then apply each simple major **one at a time**, verifying after each:

```bash
npm --prefix "$REPO" install <package>@<new-version>
OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)
```

If verify `failed`:
- If the fix is trivial (rename an import, update a config key, add a type cast,
  adjust a single call site) — make the fix, re-verify, then commit with `git add -A`.
- If fixing it requires more than trivial effort — changes across many files, API
  redesign, reading docs to understand — **reclassify it as Medium**: revert the
  install, add it to the medium list, and handle it in Step 6 instead.

```bash
npm --prefix "$REPO" install <package>@<previous-version>  # revert
```

If `passed` (either immediately or after a trivial fix), commit each simple major separately:

```bash
git -C "$REPO" add -A
git -C "$REPO" commit -m "chore: upgrade <package> to v<N>"
```

## Step 6 — Medium major updates (stacked branches)

**If the medium list is empty, skip to Step 7.**

**Do not open any PRs until this step is complete for every medium major.**

The branch structure is: `main ← $BASELINE ← medium-A | medium-B | medium-C`

Each medium major gets its own branch off `$BASELINE` and its own PR targeting `$BASELINE`.
They are independent — each branches from `$BASELINE`, not from each other.

Keep a running list of stacked PR URLs — you will need all of them for Step 7:

```bash
STACKED_PRS=()  # accumulate as: STACKED_PRS+=("<package>: <URL>")
```

For each medium major, work through 6a–6d:

**6a. Create a stacked branch from the baseline:**

```bash
OUT=$("$SCRIPTS/01-preflight.sh" "$REPO" --format json \
  --base "$BASELINE" \
  --branch "${BASELINE}-<package-name>")
STACKED_BRANCH=$(node -p "JSON.parse('$OUT').branch")
```

**6b. Apply the update, fix any breakage, and verify:**

```bash
npm --prefix "$REPO" install <package>@<new-version>
# make any required source code changes
OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)
```

If `failed`: investigate, fix source code, re-run verify. Repeat until `passed`.

If the fix turns out to be too complex (architectural, not just code changes), reclassify
as Large: check out the baseline, note the deferral reason, move to the next medium major.

```bash
git -C "$REPO" checkout "$BASELINE"
```

**Only proceed to 6c once verify is `passed`.**

**6c. Commit and open the stacked PR:**

```bash
git -C "$REPO" add -A
git -C "$REPO" commit -m "chore: upgrade <package> to v<N>"
```

Write `/tmp/pr-$(basename "$REPO")-<package>.md`:

```markdown
## Upgrade <package> to v<N>

**Why this is medium, not large:** <reason>

**What changed in the package:**
- <breaking change from changelog>

**What changed in the codebase:**
- <files modified and why>

**Merge order:** merge the baseline PR first, then this one.
```

Create the PR (targets `$BASELINE`, not `main`):

```bash
OUT=$("$SCRIPTS/05-create-pr.sh" "$REPO" "/tmp/pr-$(basename "$REPO")-<package>.md" \
  --base "$BASELINE" --format json)
STACKED_PR_URL=$(OUT="$OUT" node -p "JSON.parse(process.env.OUT).url")
STACKED_PRS+=("<package>: $STACKED_PR_URL")
```

**6d. Return to the baseline branch before the next medium major:**

```bash
git -C "$REPO" checkout "$BASELINE"
```

Repeat 6a–6d for every medium major. Only proceed to Step 7 once every medium major
has either a recorded PR URL in `$STACKED_PRS` or an explicit deferral reason.

## Step 7 — Create the baseline PR

**Only open this after Step 6 is fully complete.**

Write `/tmp/pr-$(basename "$REPO")-baseline.md` covering everything done in this workflow run:

```markdown
## Dependency management

### Removed (unused)
- `<package>` — <reason confirmed unused>

### Updated (minor/patch)
- `<package>`: <from> → <to>
- `<package>`: <from> → <to> (pinned — <reason>)

### Major updates — applied (simple, in this PR)
- `<package>`: <from> → <to> — <one-line reason it was simple>

### Major updates — stacked PRs
<!-- These PRs target this branch, not main. Merge this PR first,
     then merge each stacked PR after it lands on main. -->
- `<package>`: <PR URL>

### Major updates — deferred (large)
- `<package>`: <available version> — <reason, rough effort estimate>
```

Create:

```bash
OUT=$("$SCRIPTS/05-create-pr.sh" "$REPO" "/tmp/pr-$(basename "$REPO")-baseline.md" --format json)
BASELINE_PR_URL=$(OUT="$OUT" node -p "JSON.parse(process.env.OUT).url")
```

Report all URLs to the developer:

```
Baseline PR: $BASELINE_PR_URL
Stacked PRs (merge after baseline lands on main):
  ${STACKED_PRS[@]}
```
