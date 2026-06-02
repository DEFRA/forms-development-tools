# Dependency Management

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

The script exits. Find the offending package and revert it:

```bash
npm --prefix <repo> install <offending-dep>@<previous-version>
```

Then re-run the script. It will detect the uncommitted change to `package.json`, skip dependency installs, commit the current state, and continue to report unused dependencies and pending major updates.

---

## Handling the script's output

### Unused dependencies

The script reports what knip flagged but removes nothing. For each flagged package,
verify it is genuinely unused before removing it. Common false positives:

- `@types/*` packages — keep unless the package itself is also being removed
- Packages referenced only in config files knip doesn't scan (e.g. `jest.config.*`, `babel.config.*`)
- Peer dependencies pulled in transitively at runtime
- **String-referenced packages** — pino transports, hapi plugins registered by name, and
  webpack loaders are loaded via string at runtime; knip cannot detect these. Search the
  whole codebase for the package name as a string before concluding it is unused.

Once confirmed, uninstall, verify (build/test/lint), and commit.

### Major updates

The script lists pending major updates but does not apply them. For each, read the
changelog (`npx --yes changelog <package-name>`) and search the codebase to understand
how widely it is used. Then decide:

- **Straightforward** (minimal code changes) — apply, verify, commit.
- **Involved** (architectural changes, many call sites) — create a separate branch off
  the baseline and raise a stacked PR targeting it, or defer if you only intend to
  ship the minor/patch updates.

---

## Opening a PR

Once the branch is ready, push it and open a PR on GitHub. Use the branch name as the
title and describe what was removed, updated, and deferred in the PR body.
