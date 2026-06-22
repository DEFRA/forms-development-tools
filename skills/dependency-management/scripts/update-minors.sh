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

cd "$REPO_PATH"

# ── Preflight ──────────────────────────────────────────────────────────────────
echo "==> Preflight"
PREFLIGHT=$("$SCRIPTS/01-preflight.sh" "$REPO_PATH")
BRANCH=$(echo "$PREFLIGHT" | jq -r '.branch')

verify_and_commit() {
  local msg="$1"
  echo ""
  echo "==> Verifying"
  if ! "$SCRIPTS/04-verify.sh" "$REPO_PATH"; then
    echo ""
    echo "✗ Verification failed — see errors above."
    echo "  To revert a package: npm install <package>@<previous-version>"
    exit 1
  fi
  git add -A
  git commit -m "$msg"
  echo ""
  echo "✓ Committed on branch: $BRANCH"
}

# ── Detect updates ─────────────────────────────────────────────────────────────
echo ""
echo "==> Detecting available updates"
UPDATES_JSON=$("$SCRIPTS/03-detect-updates.sh" "$REPO_PATH")

PATCH_ARGS=$(echo "$UPDATES_JSON" | jq -r '[.updates | to_entries[] | select(.value.isMajor == false and .value.isPatch == true) | "\(.key)@\(.value.to)"] | join(" ")')
MINOR_ARGS=$(echo "$UPDATES_JSON" | jq -r '[.updates | to_entries[] | select(.value.isMajor == false and .value.isPatch == false) | "\(.key)@\(.value.to)"] | join(" ")')
MAJOR_LINES=$(echo "$UPDATES_JSON" | jq -r '.updates | to_entries[] | select(.value.isMajor == true) | "  \(.key): \(.value.from) → \(.value.to)"')

# ── Skip installs if package.json has uncommitted changes ──────────────────────
SKIP_INSTALLS=false
if [[ -n "$(git status --porcelain -- package.json)" ]]; then
  echo ""
  echo "⚠ package.json has uncommitted changes — skipping dependency installs."
  echo "  Re-run to apply remaining updates."
  SKIP_INSTALLS=true
fi

# ── Install patches ────────────────────────────────────────────────────────────
if [[ "$SKIP_INSTALLS" == false && -n "$PATCH_ARGS" ]]; then
  echo ""
  echo "==> Installing patch updates"
  # shellcheck disable=SC2086
  npm install $PATCH_ARGS
  verify_and_commit "chore: update patch dependencies"
fi

# ── Install minors ────────────────────────────────────────────────────────────
if [[ "$SKIP_INSTALLS" == false && -n "$MINOR_ARGS" ]]; then
  echo ""
  echo "==> Installing minor updates"
  # shellcheck disable=SC2086
  npm install $MINOR_ARGS
  verify_and_commit "chore: update minor dependencies"
fi

if [[ "$SKIP_INSTALLS" == false && -z "$PATCH_ARGS" && -z "$MINOR_ARGS" ]]; then
  echo "  All minor/patch dependencies are up to date."
fi

# ── Commit any remaining uncommitted changes (e.g. a manual revert) ───────────
if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "chore: update dependencies"
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
