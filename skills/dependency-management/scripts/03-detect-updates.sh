#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
FORMAT="json"
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -*)       err "Unknown option: $1" ;;
    *)        REPO_PATH="$1"; shift ;;
  esac
done

[[ -z "$REPO_PATH" ]] && err "Usage: 03-detect-updates.sh <repo-path>"
[[ ! -d "$REPO_PATH" ]] && err "Directory not found: $REPO_PATH"

cd "$REPO_PATH"

echo "Running npm-check-updates..." >&2
# ncu exits non-zero when updates are found, so || true prevents set -e from aborting
NCU_RAW=$(npx --yes npm-check-updates --jsonUpgraded --target latest 2>/dev/null || true)

NCU_RAW="$NCU_RAW" node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const allCurrent = { ...(pkg.dependencies || {}), ...(pkg.devDependencies || {}) };
const proposed = JSON.parse(process.env.NCU_RAW || '{}');
const updates = {};
for (const [name, toRange] of Object.entries(proposed)) {
  const fromRange = allCurrent[name] || '0.0.0';
  const parseParts = s => s.replace(/^[\^~>=<]+/, '').split('.').map(n => parseInt(n, 10));
  const [fromMajor, fromMinor] = parseParts(fromRange);
  const [toMajor,   toMinor  ] = parseParts(toRange);
  // unrecognised range formats (workspace:*, compound ranges) default to major so they aren't silently applied to the baseline branch
  const isMajor = (isNaN(fromMajor) || isNaN(toMajor)) ? true : toMajor > fromMajor;
  const isPatch = !isMajor && !isNaN(fromMinor) && !isNaN(toMinor) && toMinor === fromMinor;
  updates[name] = { from: fromRange, to: toRange, isMajor, isPatch };
}
console.log(JSON.stringify({ updates }));
"
