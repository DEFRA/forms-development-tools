#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
DESC_FILE=""
BASE_BRANCH="main"
DRY_RUN=false
FORMAT="tabular"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)      BASE_BRANCH="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --format)    FORMAT="$2"; shift 2 ;;
    -*)          printf '{"status":"error","error":"Unknown option: %s"}\n' "$1"; exit 1 ;;
    *)
      if [[ -z "$REPO_PATH" ]]; then REPO_PATH="$1"
      elif [[ -z "$DESC_FILE" ]]; then DESC_FILE="$1"
      fi
      shift ;;
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

if [[ -z "$REPO_PATH" || -z "$DESC_FILE" ]]; then
  err "Usage: 05-create-pr.sh <repo-path> <description-file> [--base <branch>] [--dry-run] [--format tabular|json]"
fi

[[ ! -d "$REPO_PATH" ]] && err "Directory not found: $REPO_PATH"
[[ ! -f "$DESC_FILE"  ]] && err "Description file not found: $DESC_FILE"

cd "$REPO_PATH"

BRANCH=$(git branch --show-current)
TITLE="chore: dependency management — $BRANCH"

if [[ "$DRY_RUN" == true ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    echo "DRY RUN — would execute:" >&2
    echo "  gh pr create \\" >&2
    echo "    --title \"$TITLE\" \\" >&2
    echo "    --body-file \"$DESC_FILE\" \\" >&2
    echo "    --base \"$BASE_BRANCH\" \\" >&2
    echo "    --head \"$BRANCH\"" >&2
    printf '{"status":"dry-run","title":"%s","base":"%s","head":"%s","bodyFile":"%s"}\n' \
      "$TITLE" "$BASE_BRANCH" "$BRANCH" "$DESC_FILE"
  else
    echo "Dry run — would create:"
    printf '  %-12s %s\n' "Title:"  "$TITLE"
    printf '  %-12s %s\n' "Base:"   "$BASE_BRANCH"
    printf '  %-12s %s\n' "Head:"   "$BRANCH"
    printf '  %-12s %s\n' "Body:"   "$DESC_FILE"
  fi
  exit 0
fi

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
