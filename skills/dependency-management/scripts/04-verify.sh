#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
FORMAT="tabular"
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="$2"; shift 2 ;;
    -*)       err "Unknown option: $1" ;;
    *)        REPO_PATH="$1"; shift ;;
  esac
done

[[ -z "$REPO_PATH" ]] && err "Usage: 04-verify.sh <repo-path> [--format tabular|json]"
[[ ! -d "$REPO_PATH" ]] && err "Directory not found: $REPO_PATH"

cd "$REPO_PATH"

run_step() {
  local step="$1"
  shift
  local output
  if [[ "$FORMAT" == "tabular" ]]; then
    printf '  %-8s ' "$step"
  else
    echo "Running: $*..." >&2
  fi
  if output=$("$@" 2>&1); then
    [[ "$FORMAT" == "tabular" ]] && echo "✓"
  else
    if [[ "$FORMAT" == "json" ]]; then
      jq -n --arg step "$step" --arg error "$output" '{"status":"failed","step":$step,"error":$error}'
    else
      echo "✗"
      echo "$output" | sed 's/^/    /'
    fi
    exit 1
  fi
}

[[ "$FORMAT" == "tabular" ]] && echo "Verifying:"
run_step "build" npm run build
run_step "test"  npm test
# Delete incremental tsc cache before lint so type-checking matches a clean CI run
rm -f "$REPO_PATH/tsconfig.tsbuildinfo"
run_step "lint"  npm run lint
# Run prettier check if the repo has a format:check script
if node -e "process.exit(require('./package.json').scripts?.['format:check'] ? 0 : 1)" 2>/dev/null; then
  run_step "format" npm run format:check
fi

if [[ "$FORMAT" == "json" ]]; then
  echo '{"status":"passed"}'
else
  echo "Status: passed"
fi
