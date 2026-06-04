#!/usr/bin/env bash
set -euo pipefail
SKILLS_DIR="${SKILLS_DIR:-$(cd "$(dirname "$0")" && pwd)}"
for dir in "$SKILLS_DIR"/*/; do
  if [[ -f "${dir}claude-install.sh" ]]; then
    echo "Installing $(basename "$dir")..."
    bash "${dir}claude-install.sh"
  fi
done
echo "All skills installed."
