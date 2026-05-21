#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
TARGET="latest"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    -*)       printf '{"status":"error","error":"Unknown option: %s"}\n' "$1"; exit 1 ;;
    *)        REPO_PATH="$1"; shift ;;
  esac
done

if [[ -z "$REPO_PATH" ]]; then
  echo '{"status":"error","error":"Usage: 03-update-deps.sh <repo-path> [--target patch|minor|latest]"}'
  exit 1
fi

if [[ ! -d "$REPO_PATH" ]]; then
  printf '{"status":"error","error":"Directory not found: %s"}\n' "$REPO_PATH"
  exit 1
fi

cd "$REPO_PATH"

echo "Running npm-check-updates (--target $TARGET)..." >&2
NCU_RAW=$(npx --yes npm-check-updates --jsonUpgraded --target "$TARGET" 2>/dev/null || true)

NCU_RAW="$NCU_RAW" node -e "
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
"
