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

[[ -z "$REPO_PATH" ]] && err "Usage: 02-detect-unused.sh <repo-path> [--format tabular|json]"
[[ ! -d "$REPO_PATH" ]] && err "Directory not found: $REPO_PATH"

cd "$REPO_PATH"

echo "Running knip..." >&2
KNIP_RAW=$(npx --yes knip --reporter json 2>/dev/null || true)

RESULT=$(KNIP_RAW="$KNIP_RAW" node -e "
const data = JSON.parse(process.env.KNIP_RAW);
const pkgIssue = (data.issues || []).find(i => i.file === 'package.json') || {};
const deps    = (pkgIssue.dependencies    || []).map(d => d.name);
const devDeps = (pkgIssue.devDependencies || []).map(d => d.name);
console.log(JSON.stringify({ unusedDependencies: deps, unusedDevDependencies: devDeps }));
")

if [[ "$FORMAT" == "json" ]]; then
  echo "$RESULT"
else
  RESULT="$RESULT" node -e "
const o = JSON.parse(process.env.RESULT);
const deps    = o.unusedDependencies;
const devDeps = o.unusedDevDependencies;
if (deps.length === 0 && devDeps.length === 0) {
  console.log('No unused dependencies found.');
} else {
  if (deps.length > 0) {
    console.log('Unused dependencies (' + deps.length + '):');
    deps.forEach(d => console.log('  ' + d));
  }
  if (devDeps.length > 0) {
    if (deps.length > 0) console.log('');
    console.log('Unused devDependencies (' + devDeps.length + '):');
    devDeps.forEach(d => console.log('  ' + d));
  }
}
"
fi
