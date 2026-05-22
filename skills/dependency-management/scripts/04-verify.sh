#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
FORMAT="tabular"

while [[ $# -gt 0 ]]; do
  case "$1" in
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

[[ -z "$REPO_PATH" ]] && err "Usage: 04-verify.sh <repo-path> [--format tabular|json]"
[[ ! -d "$REPO_PATH" ]] && err "Directory not found: $REPO_PATH"

cd "$REPO_PATH"

run_step() {
  local step="$1"
  local cmd="$2"
  local output
  if [[ "$FORMAT" == "tabular" ]]; then
    printf '  %-8s ' "$step"
  else
    echo "Running: $cmd..." >&2
  fi
  if output=$(eval "$cmd" 2>&1); then
    [[ "$FORMAT" == "tabular" ]] && echo "✓"
  else
    if [[ "$FORMAT" == "json" ]]; then
      STEP="$step" ERR="$output" node -e "
console.log(JSON.stringify({ status: 'failed', step: process.env.STEP, error: process.env.ERR }));
"
    else
      echo "✗"
      echo "$output" | sed 's/^/    /'
    fi
    exit 1
  fi
}

[[ "$FORMAT" == "tabular" ]] && echo "Verifying:"
run_step "build" "npm run build"
run_step "test"  "npm test"
run_step "lint"  "npm run lint"

if [[ "$FORMAT" == "json" ]]; then
  echo '{"status":"passed"}'
else
  echo "Status: passed"
fi
