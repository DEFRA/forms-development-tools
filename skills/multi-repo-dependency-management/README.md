# Multi-Repo Dependency Management

Orchestrates the [`dependency-management`](../dependency-management/README.md) skill across several Node.js repos in a single Claude Code session. Repos are processed one at a time in the main conversation thread so all interactive prompts (major update classification, confirmation steps) remain visible.

## Usage

Invoke the skill in Claude Code, passing the directory that contains your repos:

```
/multi-repo-dependency-management <base-directory>
```

If no argument is given, the current working directory is used.

## What it does

1. **Scans** the base directory for immediate subdirectories that contain a `package.json`
2. **Lets you select** which repos to sweep (presented in batches of 4)
3. **Runs** the full `dependency-management` skill on each selected repo in order
4. **Logs** the outcome of each repo (PRs opened, packages deferred) to `/tmp/dep-sweep-<date>.log`
5. **Prints** the full log at the end of the session

If a repo fails preflight (e.g. uncommitted changes), it is skipped and logged as `FAILED` — the sweep continues with the remaining repos.

## Prerequisites

The `dependency-management` skill must also be installed — this skill invokes it for each repo.

## Installing

From the repo root (installs all skills including `dependency-management`):

```bash
./skills/claude-install.sh
```

To install only this skill:

```bash
./skills/multi-repo-dependency-management/claude-install.sh
```

Full skill definition: [`SKILL.md`](./SKILL.md)
