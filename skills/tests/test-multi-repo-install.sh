#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0

TMPDIR_HOME=$(mktemp -d)
trap 'rm -rf "$TMPDIR_HOME"' EXIT

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../multi-repo-dependency-management" && pwd)/claude-install.sh"

if HOME="$TMPDIR_HOME" bash "$SCRIPT"; then
  : # installer ran ok
else
  echo "FAIL: installer exited nonzero"; ((++FAIL))
fi

INSTALLED_DIR="$TMPDIR_HOME/.claude/skills/multi-repo-dependency-management"

if [[ -d "$INSTALLED_DIR" ]]; then
  echo "PASS: install directory created"; ((PASS++))
else
  echo "FAIL: install directory not created"; ((++FAIL))
fi

if [[ -f "$INSTALLED_DIR/SKILL.md" ]]; then
  echo "PASS: SKILL.md installed"; ((PASS++))
else
  echo "FAIL: SKILL.md not installed"; ((++FAIL))
fi

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
