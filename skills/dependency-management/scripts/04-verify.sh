#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-}"

if [[ -z "$REPO_PATH" ]]; then
  echo '{"status":"error","error":"Usage: 04-verify.sh <repo-path>"}'
  exit 1
fi

if [[ ! -d "$REPO_PATH" ]]; then
  printf '{"status":"error","error":"Directory not found: %s"}\n' "$REPO_PATH"
  exit 1
fi

cd "$REPO_PATH"

run_step() {
  local step="$1"
  local cmd="$2"
  echo "Running: $cmd..." >&2
  local output
  if ! output=$(eval "$cmd" 2>&1); then
    STEP="$step" ERR="$output" node -e "
console.log(JSON.stringify({ status: 'failed', step: process.env.STEP, error: process.env.ERR }));
"
    exit 1
  fi
}

run_step "build" "npm run build"
run_step "test"  "npm test"
run_step "lint"  "npm run lint"

echo '{"status":"passed"}'
