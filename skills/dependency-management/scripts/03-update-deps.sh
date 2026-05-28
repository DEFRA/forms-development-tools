#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
TARGET="latest"
FORMAT="tabular"
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    -*)       err "Unknown option: $1" ;;
    *)        REPO_PATH="$1"; shift ;;
  esac
done

[[ -z "$REPO_PATH" ]] && err "Usage: 03-update-deps.sh <repo-path> [--target patch|minor|latest] [--format tabular|json]"
[[ ! -d "$REPO_PATH" ]] && err "Directory not found: $REPO_PATH"

cd "$REPO_PATH"

echo "Running npm-check-updates (--target $TARGET)..." >&2
NCU_RAW=$(npx --yes npm-check-updates --jsonUpgraded --target "$TARGET" 2>/dev/null || true)

RESULT=$(NCU_RAW="$NCU_RAW" node -e "
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
  updates[name] = { from: fromRange, to: toRange, isMajor: toMajor > fromMajor };
}
console.log(JSON.stringify({ updates }));
")

if [[ "$FORMAT" == "json" ]]; then
  echo "$RESULT"
else
  RESULT="$RESULT" node -e "
const o = JSON.parse(process.env.RESULT);
const entries = Object.entries(o.updates);
if (entries.length === 0) { console.log('All dependencies are up to date.'); process.exit(0); }
const minors = entries.filter(([,v]) => !v.isMajor);
const majors = entries.filter(([,v]) =>  v.isMajor);
const col = 42;
const row = (name, from, to) =>
  '  ' + name.padEnd(col) + from.padEnd(16) + to;
if (minors.length > 0) {
  console.log('Minor/patch updates (' + minors.length + '):');
  console.log('  ' + 'Package'.padEnd(col) + 'From'.padEnd(16) + 'To');
  console.log('  ' + '-'.repeat(col + 32));
  minors.forEach(([k,v]) => console.log(row(k, v.from, v.to)));
}
if (majors.length > 0) {
  if (minors.length > 0) console.log('');
  console.log('Major updates (' + majors.length + '):');
  console.log('  ' + 'Package'.padEnd(col) + 'From'.padEnd(16) + 'To');
  console.log('  ' + '-'.repeat(col + 32));
  majors.forEach(([k,v]) => console.log(row(k, v.from, v.to)));
}
"
fi
