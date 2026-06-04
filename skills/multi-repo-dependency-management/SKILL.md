---
name: multi-repo-dependency-management
description: Use when performing a dependency sweep across multiple repos. Scans a base directory for repos with package.json, lets user select which to update, then runs the dependency-management skill on each sequentially in the main thread.
argument-hint: [base-directory]
---

# Multi-Repo Dependency Management

## When to use

When you want to run dependency sweeps across several Node.js repos in one session.
Runs one repo at a time in the main conversation thread so all interactive prompts remain visible.

## Setup

Resolve the base directory from `$ARGUMENTS`. Default to `pwd` if empty:

```bash
BASE_DIR="${ARGUMENTS:-$(pwd)}"
```

Confirm it exists. If it does not, report the error and stop:

```bash
test -d "$BASE_DIR" || { echo "Error: '$BASE_DIR' does not exist."; exit 1; }
```

## Step 1 — Scan for repos

Find immediate subdirectories that contain a `package.json`:

```bash
find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d -exec test -f "{}/package.json" \; -print | sort
```

Collect the results into a list. If none are found, report "No repos with package.json found in $BASE_DIR" and stop.

## Step 2 — Select repos

Batch the repos into groups of 4. For each batch, make one sequential call to `AskUserQuestion`:

- `questions`: a single question with:
  - `question`: `"Which repos to include? (X of Y)"` — where X is the current batch number, Y is the total number of batches
  - `header`: `"Select repos"`
  - `multiSelect`: `true`
  - `options`: up to 4 entries, one per repo in this batch. Each option's `label` is the repo basename; `description` is its absolute path.

Make `ceil(N/4)` sequential calls. For each selected option, accumulate its `description` (the absolute repo path) into `SELECTED` — not the `label`.

After all batches: state "Running sweep on N repos: repo1, repo2, ..." and proceed immediately — do not ask for further confirmation.

If nothing is selected across all batches, report "No repos selected. Nothing to do." and stop.

## Step 3 — Initialise log

```bash
LOG="/tmp/dep-sweep-$(date +%Y-%m-%d).log"
```

Write the header line to `$LOG` directly, substituting the actual repo count and names you collected from Step 2:

```
Dependency sweep — YYYY-MM-DD — N repos: repo-a, repo-b, ...

```

## Step 4 — Iterate

For each repo in `SELECTED` in order (index I, total N):

**4a.** Announce to the user:
> "Starting repo I/N: <repo-basename>"

**4b.** Invoke the `dependency-management` skill via the `Skill` tool, passing the absolute repo path as the argument.

The skill runs fully in the main conversation thread. All prompts — including the major update classification in its Step 4 — are interactive and require your input as normal. If the inner skill stops with an error (e.g. preflight fails due to uncommitted changes), append `<repo-basename>: FAILED — <reason>` to `$LOG` and continue to the next repo. Process repos one at a time. Do not use subagents or the Agent tool to parallelize invocations.

**4c.** Once the skill completes, append a summary block to `$LOG`. Write this from your own knowledge of what was just completed — no additional user input required:

```
<repo-basename>:   <outcome, e.g. "3 minor/patch updated, 1 stacked PR, 1 deferred">
  Baseline PR:  <URL or "(none)">
  Stacked PRs:  <URL — package-name> ... (or "(none)")
  Deferred:     <package-name (reason)> ... (or "(none)")

```

If the inner skill failed hard, write instead:
```
<repo-basename>:   FAILED
  Reason: <error summary>

```

Include every PR URL that the dependency-management skill reported.

## Step 5 — Final summary

```bash
cat "$LOG"
```

Print the full log to the conversation.
