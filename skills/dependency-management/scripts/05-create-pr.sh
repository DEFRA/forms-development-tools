#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
DESC_FILE=""
BASE_BRANCH="main"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)      BASE_BRANCH="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    -*)          printf '{"status":"error","error":"Unknown option: %s"}\n' "$1"; exit 1 ;;
    *)
      if [[ -z "$REPO_PATH" ]]; then REPO_PATH="$1"
      elif [[ -z "$DESC_FILE" ]]; then DESC_FILE="$1"
      fi
      shift ;;
  esac
done

if [[ -z "$REPO_PATH" || -z "$DESC_FILE" ]]; then
  echo '{"status":"error","error":"Usage: 05-create-pr.sh <repo-path> <description-file> [--base <branch>] [--dry-run]"}'
  exit 1
fi

if [[ ! -d "$REPO_PATH" ]]; then
  printf '{"status":"error","error":"Directory not found: %s"}\n' "$REPO_PATH"
  exit 1
fi

if [[ ! -f "$DESC_FILE" ]]; then
  printf '{"status":"error","error":"Description file not found: %s"}\n' "$DESC_FILE"
  exit 1
fi

cd "$REPO_PATH"

BRANCH=$(git branch --show-current)
TITLE="chore: dependency management — $BRANCH"

if [[ "$DRY_RUN" == true ]]; then
  echo "DRY RUN — would execute:" >&2
  echo "  gh pr create \\" >&2
  echo "    --title \"$TITLE\" \\" >&2
  echo "    --body-file \"$DESC_FILE\" \\" >&2
  echo "    --base \"$BASE_BRANCH\" \\" >&2
  echo "    --head \"$BRANCH\"" >&2
  printf '{"status":"dry-run","title":"%s","base":"%s","head":"%s","bodyFile":"%s"}\n' \
    "$TITLE" "$BASE_BRANCH" "$BRANCH" "$DESC_FILE"
  exit 0
fi

echo "Creating PR from '$BRANCH' into '$BASE_BRANCH'..." >&2
PR_URL=$(gh pr create \
  --title "$TITLE" \
  --body-file "$DESC_FILE" \
  --base "$BASE_BRANCH" \
  --head "$BRANCH")

printf '{"status":"created","url":"%s"}\n' "$PR_URL"
