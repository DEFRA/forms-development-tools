#!/usr/bin/env bash
set -uo pipefail
SKILLS_DIR="${SKILLS_DIR:-$(cd "$(dirname "$0")" && pwd)}"
FAILED=0
for dir in "$SKILLS_DIR"/*/; do
  if [[ -f "${dir}claude-install.sh" ]]; then
    echo "Installing $(basename "$dir")..."
    if ! bash "${dir}claude-install.sh"; then
      echo "ERROR: $(basename "$dir") installer failed" >&2
      FAILED=1
    fi
  fi
done
if [[ $FAILED -eq 0 ]]; then
  echo "All skills installed."
else
  echo "Some installers failed — check errors above." >&2
  exit 1
fi
