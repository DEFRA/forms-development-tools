#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
BASE_BRANCH="origin/main"
BRANCH_NAME=""
FORMAT="json"
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)   BASE_BRANCH="$2"; shift 2 ;;
    --branch) BRANCH_NAME="$2"; shift 2 ;;
    -*)       err "Unknown option: $1" ;;
    *)        REPO_PATH="$1"; shift ;;
  esac
done

if [[ -z "$REPO_PATH" ]]; then
  err "Usage: 01-preflight.sh <repo-path> [--base <branch>] [--branch <name>]"
fi

[[ ! -d "$REPO_PATH" ]] && err "Directory not found: $REPO_PATH"

cd "$REPO_PATH"

if [[ -z "$BRANCH_NAME" ]]; then
  BRANCH_NAME="chore/dependency-management-$(date +%Y-%m-%d)"
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -n "$(git status --porcelain)" ]]; then
  if [[ "$CURRENT_BRANCH" == "$BRANCH_NAME" ]]; then
    echo "Resuming on branch '$BRANCH_NAME' with uncommitted changes..." >&2
  else
    err "Uncommitted changes found. Clean up first: git stash or git reset --hard HEAD"
  fi
fi

echo "Fetching from origin..." >&2
git fetch origin >&2 || echo "Warning: could not fetch from origin (continuing with local refs)" >&2

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  echo "Branch '$BRANCH_NAME' already exists — checking out..." >&2
  git checkout "$BRANCH_NAME" >&2
else
  echo "Creating branch '$BRANCH_NAME' from '$BASE_BRANCH'..." >&2
  git checkout -b "$BRANCH_NAME" "$BASE_BRANCH" >&2
fi

printf '{"branch":"%s","status":"ready"}\n' "$BRANCH_NAME"
