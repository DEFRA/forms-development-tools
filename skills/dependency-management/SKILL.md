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
OUT=$("$SCRIPTS/01-preflight.sh" <repo-path>)
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
OUT=$("$SCRIPTS/02-detect-unused.sh" <repo-path>)
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
OUT=$("$SCRIPTS/04-verify.sh" <repo-path>)
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

## Step 4 — Detect available updates

```bash
OUT=$("$SCRIPTS/03-update-deps.sh" <repo-path> --target latest)
```

Separate the output into:
- Minor/patch updates (`isMajor: false`) — apply all
- Major updates (`isMajor: true`) — classify each:

**Classification criteria (cognitive complexity, not file count):**
- **Simple**: changelog shows only renamed/moved exports, no behaviour change.
  Or: codebase does not use the changed API at all. Apply in baseline branch.
- **Medium**: changelog shows bounded breaking changes affecting code we use,
  requiring straightforward (non-architectural) updates. Stacked PR.
- **Large**: migration requires redesigning how the package integrates,
  evaluating alternatives, or understanding architectural trade-offs. Defer.

To read a changelog:

```bash
npx --yes changelog <package-name>
```

To check codebase usage of a package:

```bash
grep -r "from '<package-name>" <repo-path>/src --include="*.ts" --include="*.js" -l
```

## Step 5 — Apply minor/patch and simple major updates

Apply updates using npm — it handles `package.json` and the lockfile atomically:

```bash
npm --prefix <repo-path> install dep1@^x.y.z dep2@^x.y.z ...
OUT=$("$SCRIPTS/04-verify.sh" <repo-path>)
```

If `failed`: identify which update broke CI (binary search by reverting half
the updates and re-verifying). Pin the offender at its previous version:

```bash
npm --prefix <repo-path> install <offending-dep>@<previous-version>
```

Re-verify. Repeat until `passed`.

Commit:

```bash
git -C <repo-path> add package.json package-lock.json
git -C <repo-path> commit -m "chore: update dependencies to latest minor/patch"
```

For each simple major applied, add a separate commit:

```bash
git -C <repo-path> commit -m "chore: upgrade <package> to v<N>"
```

## Step 6 — Handle medium major updates (stacked PRs)

For each medium major update, create a stacked branch from the baseline:

```bash
OUT=$("$SCRIPTS/01-preflight.sh" <repo-path> \
  --base "$BASELINE" \
  --branch "${BASELINE}-<package-name>")
STACKED_BRANCH=$(node -p "JSON.parse('$OUT').branch")
```

Apply the update using npm, then make any required source code changes:

```bash
npm --prefix <repo-path> install <package>@<new-version>
# make any required source code changes
OUT=$("$SCRIPTS/04-verify.sh" <repo-path>)
```

If failed: investigate, fix, re-verify. If the fix is too complex, reclassify
as Large, revert the branch (`git -C <repo-path> checkout "$BASELINE"`), and
document the deferral.

When passing, commit and write the stacked PR description to a temp file:

```markdown
## Upgrade <package> to v<N>

**Why:** <reason this is a medium, not large, migration>

**What changed in the package:**
- <breaking change from changelog>

**What changed in the codebase:**
- <files modified and why>
```

Verify first, then create:

```bash
"$SCRIPTS/05-create-pr.sh" <repo-path> /tmp/pr-<package>.md \
  --base "$BASELINE" --dry-run

OUT=$("$SCRIPTS/05-create-pr.sh" <repo-path> /tmp/pr-<package>.md \
  --base "$BASELINE")
STACKED_PR_URL=$(node -p "JSON.parse('$OUT').url")
```

Repeat for each medium major. **Always use `--base "$BASELINE"`** — stacked
PRs are independent of each other, all branching from the baseline.

Switch back to baseline when done with all stacked PRs:

```bash
git -C <repo-path> checkout "$BASELINE"
```

## Step 7 — Create the baseline PR

Write a PR description to `/tmp/pr-baseline.md` covering all decisions made:

```markdown
## Dependency management

### Removed (unused)
- `<package>` — <reason confirmed unused>

### Updated (minor/patch)
- `<package>`: <from> → <to>

### Major updates — applied (simple)
- `<package>`: <from> → <to> — <one-line reason it was simple>

### Major updates — stacked PRs
- `<package>`: <stacked PR URL>

### Major updates — deferred (large)
- `<package>`: <available version> — <reason for deferral, rough effort estimate>
```

Verify first, then create:

```bash
"$SCRIPTS/05-create-pr.sh" <repo-path> /tmp/pr-baseline.md --dry-run

OUT=$("$SCRIPTS/05-create-pr.sh" <repo-path> /tmp/pr-baseline.md)
node -p "JSON.parse('$OUT').url"
```

Report the PR URLs to the developer.
