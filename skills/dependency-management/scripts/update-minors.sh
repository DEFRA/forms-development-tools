#!/usr/bin/env bash
# Applies all minor/patch updates to a target repo, verifies, and commits.
# Reports unused dependencies and pending major updates for follow-up.
set -euo pipefail

SCRIPTS="$(dirname "$0")"
REPO_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -*) echo "Error: Unknown option: $1" >&2; exit 1 ;;
    *)  REPO_PATH="$1"; shift ;;
  esac
done

if [[ -z "$REPO_PATH" ]]; then
  echo "Usage: update-minors.sh <repo-path>" >&2
  exit 1
fi

[[ ! -d "$REPO_PATH" ]] && echo "Error: Directory not found: $REPO_PATH" >&2 && exit 1

# ── Preflight ──────────────────────────────────────────────────────────────────
echo "==> Preflight"
PREFLIGHT=$("$SCRIPTS/01-preflight.sh" "$REPO_PATH")
BRANCH=$(echo "$PREFLIGHT" | jq -r '.branch')

# ── Detect updates ─────────────────────────────────────────────────────────────
echo ""
echo "==> Detecting available updates"
UPDATES_JSON=$("$SCRIPTS/03-detect-updates.sh" "$REPO_PATH")

MINOR_ARGS=$(echo "$UPDATES_JSON" | jq -r '[.updates | to_entries[] | select(.value.isMajor == false) | "\(.key)@\(.value.to)"] | join(" ")')

MAJOR_LINES=$(echo "$UPDATES_JSON" | jq -r '.updates | to_entries[] | select(.value.isMajor == true) | "  \(.key): \(.value.from) → \(.value.to)"')

# ── Install minor/patch ────────────────────────────────────────────────────────
if [[ -z "$MINOR_ARGS" ]]; then
  echo "  All minor/patch dependencies are up to date."
else
  echo ""
  echo "==> Installing minor/patch updates"
  # shellcheck disable=SC2086
  npm --prefix "$REPO_PATH" install $MINOR_ARGS

  echo ""
  echo "==> Verifying"
  if ! "$SCRIPTS/04-verify.sh" "$REPO_PATH"; then
    echo ""
    echo "✗ Verification failed — see errors above."
    echo "  To revert a package: npm --prefix \"$REPO_PATH\" install <package>@<previous-version>"
    exit 1
  fi

  git -C "$REPO_PATH" add -A
  git -C "$REPO_PATH" commit -m "chore: update dependencies to latest minor/patch"
  echo ""
  echo "✓ Committed on branch: $BRANCH"
fi

# ── Follow-up ──────────────────────────────────────────────────────────────────
echo ""
echo "── Follow-up ────────────────────────────────────────────────────────────────"
echo ""
echo "==> Scanning for unused dependencies"
"$SCRIPTS/02-detect-unused.sh" "$REPO_PATH"

if [[ -n "$MAJOR_LINES" ]]; then
  echo ""
  echo "==> Major updates pending (need review)"
  echo "$MAJOR_LINES"
  echo ""
  echo "  Run the AI dependency-management skill to classify and apply these."
fi
