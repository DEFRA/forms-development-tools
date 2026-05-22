---
name: dependency-management
description: Run a full dependency management sweep on a Node.js microservice — remove unused deps, update to latest versions (including safe major upgrades), verify CI, and open stacked PRs. Invoke with the target repo path.
disable-model-invocation: true
allowed-tools: Bash
---

# Dependency Management Skill

## When to use

When a developer wants to run a dependency sweep on one of the forms-* microservices.
One repo at a time. Target `forms-runner` first, then repeat for others.

## Setup

Scripts are bundled with this skill. Set `SCRIPTS` once at the start of the session:

```bash
SCRIPTS="${CLAUDE_SKILL_DIR}/scripts"
```

## Step 1 — Preflight

```bash
OUT=$("$SCRIPTS/01-preflight.sh" <repo-path> --format json)
```

Check `status` in output. If `error`, report to the user and stop — the repo
has uncommitted changes that must be resolved first.

If `ready`, store the branch name:

```bash
BASELINE=$(node -p "JSON.parse('$OUT').branch")
```

**If resuming on a later day:** read the branch from git instead:

```bash
BASELINE=$(git -C <repo-path> branch --show-current)
```

## Step 2 — Detect unused dependencies

```bash
OUT=$("$SCRIPTS/02-detect-unused.sh" <repo-path> --format json)
UNUSED_DEPS=$(node -p "JSON.parse('$OUT').unusedDependencies.join(', ')")
UNUSED_DEV=$(node -p "JSON.parse('$OUT').unusedDevDependencies.join(', ')")
```

For each flagged dependency, examine the codebase to confirm it is genuinely
unused — not dynamically required, loaded via framework plugin, or referenced
only in config. Common false positives:

- `@types/*` packages referenced only by TypeScript (always keep unless the package itself is removed)
- Packages loaded in config files not scanned by knip (e.g. `.babelrc`, `jest.config.*`)
- Peer dependencies pulled in transitively by other packages at runtime
- **String-referenced packages** — pino transports (`target: 'pino-pretty'`), hapi plugins
  registered by name, webpack loaders, and similar patterns load packages via string at
  runtime. Knip cannot detect these. Search for the package name as a string, not just
  as an import, before removing:
  ```bash
  grep -r "'<package-name>'\|\"<package-name>\"" <repo-path>/src --include="*.ts" --include="*.js"
  ```

Remove confirmed unused deps. npm handles `package.json` and the lockfile atomically:

```bash
npm --prefix <repo-path> uninstall <dep1> <dep2> ...
```

## Step 3 — Verify removals

```bash
OUT=$("$SCRIPTS/04-verify.sh" <repo-path> --format json)
STATUS=$(node -p "JSON.parse('$OUT').status")
```

If `failed`: read `step` and `error` from output. Investigate which removed
dep caused the failure, restore it and re-verify:

```bash
npm --prefix <repo-path> install <dep>
```

Repeat until `passed`.

Commit:

```bash
git -C <repo-path> add package.json package-lock.json
git -C <repo-path> commit -m "chore: remove unused dependencies"
```

## Step 4 — Detect and classify all available updates

```bash
OUT=$("$SCRIPTS/03-update-deps.sh" <repo-path> --target latest --format json)
```

Classify every update before applying any of them:
- Minor/patch (`isMajor: false`) — all go into the baseline branch
- Major (`isMajor: true`) — classify each individually:

**Classification criteria (cognitive complexity, not file count):**
- **Simple** — no usage changes needed, or purely mechanical find/replace. Goes into baseline branch.
- **Medium** — bounded code changes that are straightforward but non-trivial. Gets its own stacked branch and PR.
- **Large** — requires architectural decisions, significant rethinking, or evaluation of alternatives. Deferred and documented.

To read a changelog:

```bash
npx --yes changelog <package-name>
```

To check codebase usage of a package:

```bash
grep -r "from '<package-name>" <repo-path>/src --include="*.ts" --include="*.js" -l
```

After classifying, record three explicit lists before proceeding:
- **Simple majors** (will be applied in Step 5 alongside minor/patch)
- **Medium majors** (will each get a stacked branch and PR in Step 6 — this is mandatory, not optional)
- **Large majors** (will be deferred and documented in the baseline PR)

## Step 5 — Apply minor/patch and simple major updates (baseline branch)

You are on `$BASELINE` throughout this step.

Apply minor/patch updates and simple majors using npm:

```bash
npm --prefix <repo-path> install dep1@^x.y.z dep2@^x.y.z ...
OUT=$("$SCRIPTS/04-verify.sh" <repo-path> --format json)
```

If `failed`: identify which update broke CI (binary search by reverting half
the updates and re-verifying). Pin the offender at its previous version:

```bash
npm --prefix <repo-path> install <offending-dep>@<previous-version>
```

Re-verify. Repeat until `passed`.

Commit all minor/patch updates together:

```bash
git -C <repo-path> add package.json package-lock.json
git -C <repo-path> commit -m "chore: update dependencies to latest minor/patch"
```

For each simple major, a separate commit:

```bash
git -C <repo-path> commit -m "chore: upgrade <package> to v<N>"
```

## Step 6 — Medium major updates (stacked branches) — MANDATORY

**Do not open any PRs until this step is complete for every medium major.**

The branch structure is: `main ← $BASELINE ← medium-A | medium-B | medium-C`

Each medium major gets its own branch off `$BASELINE` and its own PR targeting `$BASELINE`.
They are independent — each branches from `$BASELINE`, not from each other.

For each medium major:

**6a. Create a stacked branch from the baseline:**

```bash
OUT=$("$SCRIPTS/01-preflight.sh" <repo-path> --format json \
  --base "$BASELINE" \
  --branch "${BASELINE}-<package-name>")
STACKED_BRANCH=$(node -p "JSON.parse('$OUT').branch")
```

**6b. Apply the update and fix any breakage:**

```bash
npm --prefix <repo-path> install <package>@<new-version>
# make any required source code changes
OUT=$("$SCRIPTS/04-verify.sh" <repo-path> --format json)
```

If failed: investigate, fix, re-verify. If the fix turns out to be too complex,
reclassify as Large: check out the baseline (`git -C <repo-path> checkout "$BASELINE"`),
note it in the deferred list, and move on to the next medium major.

**6c. Commit and open the stacked PR:**

```bash
git -C <repo-path> add -A
git -C <repo-path> commit -m "chore: upgrade <package> to v<N>"
```

Write `/tmp/pr-<package>.md`:

```markdown
## Upgrade <package> to v<N>

**Why:** <reason this is medium, not large>

**What changed in the package:**
- <breaking change from changelog>

**What changed in the codebase:**
- <files modified and why>
```

```bash
"$SCRIPTS/05-create-pr.sh" <repo-path> /tmp/pr-<package>.md \
  --base "$BASELINE" --dry-run

OUT=$("$SCRIPTS/05-create-pr.sh" <repo-path> /tmp/pr-<package>.md \
  --base "$BASELINE" --format json)
STACKED_PR_URL=$(node -p "JSON.parse('$OUT').url")
```

Record the PR URL — it goes into the baseline PR body in Step 7.

**6d. Return to the baseline branch before the next medium major:**

```bash
git -C <repo-path> checkout "$BASELINE"
```

Repeat 6a–6d for every medium major. Only proceed to Step 7 once all medium
majors have either a stacked PR URL or a deferral reason.

## Step 7 — Create the baseline PR

**Only open this after Step 6 is fully complete.**

Write `/tmp/pr-baseline.md` covering everything done in this workflow run:

```markdown
## Dependency management

### Removed (unused)
- `<package>` — <reason confirmed unused>

### Updated (minor/patch)
- `<package>`: <from> → <to>

### Major updates — applied (simple, in this PR)
- `<package>`: <from> → <to> — <one-line reason it was simple>

### Major updates — stacked PRs (merge after this PR lands)
- `<package>`: <PR URL>

### Major updates — deferred (large)
- `<package>`: <available version> — <reason, rough effort estimate>
```

```bash
"$SCRIPTS/05-create-pr.sh" <repo-path> /tmp/pr-baseline.md --dry-run

OUT=$("$SCRIPTS/05-create-pr.sh" <repo-path> /tmp/pr-baseline.md --format json)
node -p "JSON.parse('$OUT').url"
```

Report all PR URLs to the developer: the baseline PR first, then each stacked PR.
