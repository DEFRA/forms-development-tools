#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
DESC_FILE=""
BASE_BRANCH="main"
FORMAT="tabular"
TITLE="chore: bulk dependency update"
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)      BASE_BRANCH="$2"; shift 2 ;;
    --format)    FORMAT="$2"; shift 2 ;;
    --title)     TITLE="$2"; shift 2 ;;
    -*)          err "Unknown option: $1" ;;
    *)
      if [[ -z "$REPO_PATH" ]]; then REPO_PATH="$1"
      elif [[ -z "$DESC_FILE" ]]; then DESC_FILE="$1"
      fi
      shift ;;
  esac
done

if [[ -z "$REPO_PATH" || -z "$DESC_FILE" ]]; then
  err "Usage: 05-create-pr.sh <repo-path> <description-file> [--base <branch>] [--title <title>] [--format tabular|json]"
fi

[[ ! -d "$REPO_PATH" ]] && err "Directory not found: $REPO_PATH"
[[ ! -f "$DESC_FILE"  ]] && err "Description file not found: $DESC_FILE"

cd "$REPO_PATH"

BRANCH=$(git branch --show-current)
TITLE="chore: dependency management"

echo "Creating PR from '$BRANCH' into '$BASE_BRANCH'..." >&2
PR_URL=$(gh pr create \
  --title "$TITLE" \
  --body-file "$DESC_FILE" \
  --base "$BASE_BRANCH" \
  --head "$BRANCH")

if [[ "$FORMAT" == "json" ]]; then
  printf '{"status":"created","url":"%s"}\n' "$PR_URL"
else
  echo "PR created: $PR_URL"
fi
