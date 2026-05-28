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

[[ -z "$REPO_PATH" ]] && err "Usage: 03-update-deps.sh <repo-path> [--format tabular|json]"
[[ ! -d "$REPO_PATH" ]] && err "Directory not found: $REPO_PATH"

cd "$REPO_PATH"

echo "Running npm-check-updates..." >&2
# ncu exits non-zero when updates are found, so || true prevents set -e from aborting
NCU_RAW=$(npx --yes npm-check-updates --jsonUpgraded --target latest 2>/dev/null || true)

NCU_RAW="$NCU_RAW" FORMAT="$FORMAT" node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const allCurrent = { ...(pkg.dependencies || {}), ...(pkg.devDependencies || {}) };
const proposed = JSON.parse(process.env.NCU_RAW || '{}');
const updates = {};
for (const [name, toRange] of Object.entries(proposed)) {
  const fromRange = allCurrent[name] || '0.0.0';
  const stripRange = s => s.replace(/^[\^~>=<]+/, '').split('.')[0];
  const fromMajor = parseInt(stripRange(fromRange), 10);
  const toMajor   = parseInt(stripRange(toRange),   10);
  // unrecognised range formats (workspace:*, compound ranges) default to major so they aren't silently applied to the baseline branch
  const isMajor = (isNaN(fromMajor) || isNaN(toMajor)) ? true : toMajor > fromMajor;
  updates[name] = { from: fromRange, to: toRange, isMajor };
}
if (process.env.FORMAT === 'json') {
  console.log(JSON.stringify({ updates }));
} else {
  const entries = Object.entries(updates);
  if (entries.length === 0) { console.log('All dependencies are up to date.'); process.exit(0); }
  const minors = entries.filter(([,v]) => !v.isMajor);
  const majors = entries.filter(([,v]) =>  v.isMajor);
  const PACKAGE_COL = 42;
  const VERSION_COL = 16;
  const row = (name, from, to) =>
    '  ' + name.padEnd(PACKAGE_COL) + from.padEnd(VERSION_COL) + to;
  if (minors.length > 0) {
    console.log('Minor/patch updates (' + minors.length + '):');
    console.log('  ' + 'Package'.padEnd(PACKAGE_COL) + 'From'.padEnd(VERSION_COL) + 'To');
    console.log('  ' + '-'.repeat(PACKAGE_COL + VERSION_COL * 2));
    minors.forEach(([k,v]) => console.log(row(k, v.from, v.to)));
  }
  if (majors.length > 0) {
    if (minors.length > 0) console.log('');
    console.log('Major updates (' + majors.length + '):');
    console.log('  ' + 'Package'.padEnd(PACKAGE_COL) + 'From'.padEnd(VERSION_COL) + 'To');
    console.log('  ' + '-'.repeat(PACKAGE_COL + VERSION_COL * 2));
    majors.forEach(([k,v]) => console.log(row(k, v.from, v.to)));
  }
}
"
