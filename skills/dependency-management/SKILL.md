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
OUT=$("$SCRIPTS/01-preflight.sh" "$REPO")
```

Check `status` in output. If `error`, report to the user and stop — the repo
has uncommitted changes that must be resolved first.

If `ready`, store the branch name:

```bash
BASELINE=$(echo "$OUT" | jq -r '.branch')
```

**If resuming on a later day:** read the branch from git instead of re-running preflight:

```bash
BASELINE=$(git -C "$REPO" branch --show-current)
```

Verify `$BASELINE` starts with `chore/dependency-management-` before continuing.

## Step 2 — Detect unused dependencies

```bash
OUT=$("$SCRIPTS/02-detect-unused.sh" "$REPO" --format json)
UNUSED_DEPS=$(echo "$OUT" | jq -r '.unusedDependencies | join(" ")')
UNUSED_DEV=$(echo "$OUT" | jq -r '.unusedDevDependencies | join(" ")')
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
STATUS=$(echo "$OUT" | jq -r '.status')
STEP=$(echo "$OUT" | jq -r '.step')
ERROR=$(echo "$OUT" | jq -r '.error')
```

If `failed`: use `$STEP` and `$ERROR` to identify which removed dep caused
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
OUT=$("$SCRIPTS/03-detect-updates.sh" "$REPO")
UPDATE_COUNT=$(echo "$OUT" | jq '.updates | length')
```

**If `$UPDATE_COUNT` is `0`, skip Steps 5 and 6 and go straight to Step 7.**

Classify every update before applying any of them:

- Minor/patch (`isMajor: false`) — all go into the baseline branch
- Major (`isMajor: true`) — classify each as **to attempt** or **deferred (large)**:

**Do not pre-classify majors as simple vs stacked.** Only decide at the changelog level
whether an update is too architectural to attempt at all. Everything else is attempted in
the baseline branch in Step 5; the actual simple/stacked decision is made from observed
effort, not changelog assumptions.

**Deferred (large) — skip without attempting** when the changelog shows:
  - Architectural rethinking required (e.g. a framework changes its rendering model, a
    validator changes its schema DSL, a linter renames half its rule set)
  - Evaluating alternatives is part of the migration (the recommended upgrade path
    involves choosing between competing options or tools)
  - The migration scope is indeterminate from the changelog alone

**To attempt — everything else.** Even packages with documented breaking changes belong
here unless they clearly meet the deferred criteria above. Breaking changes in areas the
codebase may not use, or that turn out to require only trivial fixes, are discovered in
Step 5 — not assumed now.

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

**After classifying, show the user the two lists and wait for confirmation before
proceeding:**

- Majors to attempt: `[list]` (or none — will be tried in the baseline; moved to a stacked branch only if the actual changes required are significant)
- Large majors (deferred): `[list]` (or none — too architectural to attempt in this run)

Do not proceed until the user confirms or adjusts the classification.

## Step 5 — Apply minor/patch updates and attempt major updates (baseline branch)

> **Verification rule: run `04-verify.sh` after every `npm install` without exception.**
> Never commit or proceed to the next package without a passing verify.

You are on `$BASELINE` throughout this step.

Keep a running list of majors reclassified to stacked during this step:

```bash
RECLASSIFIED_TO_STACKED=()
```

**5a — Minor/patch updates:**

Apply all minor/patch updates in one npm command:

```bash
npm --prefix "$REPO" install dep1@^x.y.z dep2@^x.y.z ...
OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)
```

If `failed`: binary search to find the offending update. Pin it at its previous version:

```bash
npm --prefix "$REPO" install <offending-dep>@<previous-version>
OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)
```

Repeat until `passed`. Note any pinned packages for the PR body.

Commit:

```bash
git -C "$REPO" add -A
git -C "$REPO" commit -m "chore: update dependencies to latest minor/patch"
```

**5b — Major updates (attempt in baseline, decide from observed effort):**

Attempt each major in the "to attempt" list **one at a time**:

```bash
npm --prefix "$REPO" install <package>@<new-version>
OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)
```

**Decide based on what you observe — not on changelog assumptions:**

- **Passed immediately:** commit to baseline.
  ```bash
  git -C "$REPO" add -A
  git -C "$REPO" commit -m "chore: upgrade <package> to v<N>"
  ```

- **Failed with a trivial fix** (rename an import, update a config key, add a type cast,
  adjust a single call site — fixed in under 10 minutes without reading docs): make the
  fix, re-verify, then commit to baseline.
  ```bash
  # make fix
  OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)
  git -C "$REPO" add -A
  git -C "$REPO" commit -m "chore: upgrade <package> to v<N>"
  ```

- **Failed and fixing requires significant effort** (changes across many files, new
  required options throughout, method signatures changed in several places, reading docs
  to understand the migration): **reclassify as stacked.** Revert and add to the stacked list.
  ```bash
  npm --prefix "$REPO" install <package>@<previous-version>
  OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)  # verify the revert
  RECLASSIFIED_TO_STACKED+=("<package>@<new-version>")
  ```

- **Failed and turns out architectural** (not just code changes — requires evaluating
  options or rethinking structure): **reclassify as deferred (large).** Revert and note
  the reason.
  ```bash
  npm --prefix "$REPO" install <package>@<previous-version>
  OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)  # verify the revert
  ```

The threshold for stacking is observed effort, not changelog language. A package with
documented breaking changes that requires no code changes stays in the baseline. A
package that seemed minor but requires touching many files moves to a stacked branch.

## Step 6 — Stacked major updates (reclassified during Step 5)

**If `$RECLASSIFIED_TO_STACKED` is empty, skip to Step 7.**

**Do not open any PRs until this step is complete for every stacked major.**

The branch structure is: `main ← $BASELINE ← stacked-A | stacked-B | stacked-C`

Each stacked major gets its own branch off `$BASELINE` and its own PR targeting `$BASELINE`.
They are independent — each branches from `$BASELINE`, not from each other.

Keep a running list of stacked PR URLs — you will need all of them for Step 7:

```bash
STACKED_PRS=()  # accumulate as: STACKED_PRS+=("<package>: <URL>")
```

For each stacked major in `$RECLASSIFIED_TO_STACKED`, work through 6a–6d:

**6a. Create a stacked branch from the baseline:**

```bash
OUT=$("$SCRIPTS/01-preflight.sh" "$REPO" \
  --base "$BASELINE" \
  --branch "${BASELINE}-<package-name>")
STACKED_BRANCH=$(echo "$OUT" | jq -r '.branch')
```

**6b. Apply the update, fix any breakage, and verify:**

```bash
npm --prefix "$REPO" install <package>@<new-version>
# make any required source code changes
OUT=$("$SCRIPTS/04-verify.sh" "$REPO" --format json)
```

If `failed`: investigate, fix source code, re-run verify. Repeat until `passed`.

If the fix turns out to be too complex (architectural, not just code changes), reclassify
as Large: check out the baseline, note the deferral reason, move to the next stacked major.

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

**Why this is stacked:** <reason — what actual changes were required and why they warranted a separate PR>

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
STACKED_PR_URL=$(echo "$OUT" | jq -r '.url')
STACKED_PRS+=("<package>: $STACKED_PR_URL")
```

**6d. Return to the baseline branch before the next stacked major:**

```bash
git -C "$REPO" checkout "$BASELINE"
```

Repeat 6a–6d for every stacked major in `$RECLASSIFIED_TO_STACKED`. Only proceed to
Step 7 once every stacked major has either a recorded PR URL in `$STACKED_PRS` or an
explicit deferral reason.

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

### Major updates — applied in this PR
- `<package>`: <from> → <to> — <one-line note on what, if anything, changed in the codebase>

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
BASELINE_PR_URL=$(echo "$OUT" | jq -r '.url')
```

Report all URLs to the developer:

```
Baseline PR: $BASELINE_PR_URL
Stacked PRs (merge after baseline lands on main):
  ${STACKED_PRS[@]}
```
