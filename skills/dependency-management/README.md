# Dependency Management — Manual Runbook

Two ways to run a dependency sweep on a forms-* microservice.

---

## Mode 1 — AI skill (recommended)

Invoke `/dependency-management <repo>` in Claude Code. The skill handles everything:
unused dependency detection and removal, update classification, minor/patch updates,
stacked PRs for medium majors, and deferral of large majors.

---

## Mode 2 — update-minors.sh

For developers without AI access, the script handles minor/patch updates automatically and
reports unused dependencies and pending major updates for you to action manually.

### Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`)
- `git` configured with access to the target repo's remote
- `jq` installed (`jq --version`)
- Node.js available (scripts use `npx` for zero-install tooling)

### Run the script

Replace `<repo>` with the absolute path to the target microservice.

```bash
./skills/dependency-management/scripts/update-minors.sh <repo>
```

The script will:
1. Create branch `chore/dependency-management-<YYYY-MM-DD>` from `origin/main`
2. Report any unused dependencies (does not remove them)
3. Install all minor/patch updates in one batch
4. Run build, test, and lint to verify
5. Commit if verification passes
6. List any pending major updates

### If verification fails

The script exits and shows which packages were installed. Binary search to find the
offending package and pin it at its previous version:

```bash
npm --prefix <repo> install <offending-dep>@<previous-version>
./skills/dependency-management/scripts/04-verify.sh <repo>
```

Repeat until clean, then commit manually:

```bash
git -C <repo> add -A
git -C <repo> commit -m "chore: update dependencies to latest minor/patch"
```

---

## Handling the script's output

### Unused dependencies

The script reports what knip flagged but removes nothing. For each flagged package,
verify it is genuinely unused before removing it. Common false positives:

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

Remove confirmed unused deps, verify, and commit:

```bash
npm --prefix <repo> uninstall <dep1> <dep2> ...
./skills/dependency-management/scripts/04-verify.sh <repo>
git -C <repo> add -A
git -C <repo> commit -m "chore: remove unused dependencies"
```

### Major updates

The script lists pending major updates but does not apply them. For each, read the
changelog and check how widely the package is used in the codebase:

```bash
npx --yes changelog <package-name>

grep -rE "from ['\"]<package-name>['\"]|require\(['\"]<package-name>" <repo> \
  --include="*.ts" --include="*.js" --include="*.mjs" --include="*.cjs" -l \
  --exclude-dir=node_modules --exclude-dir=.git
```

For straightforward majors (minimal code changes, no architectural impact), apply and
verify one at a time:

```bash
npm --prefix <repo> install <package>@<new-version>
./skills/dependency-management/scripts/04-verify.sh <repo>
git -C <repo> add -A
git -C <repo> commit -m "chore: upgrade <package> to v<N>"
```

For anything more involved, use the AI skill — it classifies majors by implementation
effort, handles the required code changes, and opens stacked PRs where needed.

---

## Opening a PR

Once the branch is ready, write a description file and create the PR:

```bash
./skills/dependency-management/scripts/05-create-pr.sh <repo> <description-file>
```

---

## Resuming on a later day

Do not re-run the script. The branch already exists. Find its name:

```bash
git -C <repo> branch --show-current
```

Verify it starts with `chore/dependency-management-` before continuing.
