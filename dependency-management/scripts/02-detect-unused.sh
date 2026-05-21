#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-}"

if [[ -z "$REPO_PATH" ]]; then
  echo '{"status":"error","error":"Usage: 02-detect-unused.sh <repo-path>"}'
  exit 1
fi

if [[ ! -d "$REPO_PATH" ]]; then
  printf '{"status":"error","error":"Directory not found: %s"}\n' "$REPO_PATH"
  exit 1
fi

cd "$REPO_PATH"

echo "Running knip..." >&2
KNIP_RAW=$(npx --yes knip --reporter json 2>/dev/null || true)

KNIP_RAW="$KNIP_RAW" node -e "
const data = JSON.parse(process.env.KNIP_RAW);
const pkgIssue = (data.issues || []).find(i => i.file === 'package.json') || {};
const deps    = (pkgIssue.dependencies    || []).map(d => d.name);
const devDeps = (pkgIssue.devDependencies || []).map(d => d.name);
console.log(JSON.stringify({ unusedDependencies: deps, unusedDevDependencies: devDeps }));
"
