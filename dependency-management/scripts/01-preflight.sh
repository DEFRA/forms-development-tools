#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
BASE_BRANCH="origin/main"
BRANCH_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)   BASE_BRANCH="$2"; shift 2 ;;
    --branch) BRANCH_NAME="$2"; shift 2 ;;
    -*)       printf '{"status":"error","error":"Unknown option: %s"}\n' "$1"; exit 1 ;;
    *)        REPO_PATH="$1"; shift ;;
  esac
done

if [[ -z "$REPO_PATH" ]]; then
  echo '{"status":"error","error":"Usage: 01-preflight.sh <repo-path> [--base <branch>] [--branch <name>]"}'
  exit 1
fi

if [[ ! -d "$REPO_PATH" ]]; then
  printf '{"status":"error","error":"Directory not found: %s"}\n' "$REPO_PATH"
  exit 1
fi

cd "$REPO_PATH"

if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  echo '{"status":"error","error":"Repository has uncommitted changes or untracked files"}'
  exit 1
fi

echo "Fetching from origin..." >&2
git fetch origin >&2 || echo "Warning: could not fetch from origin (continuing with local refs)" >&2

if [[ -z "$BRANCH_NAME" ]]; then
  BRANCH_NAME="chore/dependency-management-$(date +%Y-%m-%d)"
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  echo "Branch '$BRANCH_NAME' already exists — checking out..." >&2
  git checkout "$BRANCH_NAME" >&2
else
  echo "Creating branch '$BRANCH_NAME' from '$BASE_BRANCH'..." >&2
  git checkout -b "$BRANCH_NAME" "$BASE_BRANCH" >&2
fi

printf '{"branch":"%s","status":"ready"}\n' "$BRANCH_NAME"
