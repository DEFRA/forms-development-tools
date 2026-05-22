#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
BASE_BRANCH="origin/main"
BRANCH_NAME=""
FORMAT="tabular"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)   BASE_BRANCH="$2"; shift 2 ;;
    --branch) BRANCH_NAME="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    -*)       printf '{"status":"error","error":"Unknown option: %s"}\n' "$1"; exit 1 ;;
    *)        REPO_PATH="$1"; shift ;;
  esac
done

err() {
  if [[ "$FORMAT" == "json" ]]; then
    printf '{"status":"error","error":"%s"}\n' "$1"
  else
    echo "Error: $1" >&2
  fi
  exit 1
}

if [[ -z "$REPO_PATH" ]]; then
  err "Usage: 01-preflight.sh <repo-path> [--base <branch>] [--branch <name>] [--format tabular|json]"
fi

[[ ! -d "$REPO_PATH" ]] && err "Directory not found: $REPO_PATH"

cd "$REPO_PATH"

if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  err "Repository has uncommitted changes or untracked files"
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

if [[ "$FORMAT" == "json" ]]; then
  printf '{"branch":"%s","status":"ready"}\n' "$BRANCH_NAME"
else
  printf '%-10s %s\n' "Branch:" "$BRANCH_NAME"
  printf '%-10s %s\n' "Status:" "ready"
fi
