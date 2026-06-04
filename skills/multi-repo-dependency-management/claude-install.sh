#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$HOME/.claude/skills/multi-repo-dependency-management"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing multi-repo-dependency-management skill to $SKILL_DIR..."
mkdir -p "$SKILL_DIR"
cp "$SOURCE_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
echo "Done. Invoke with /multi-repo-dependency-management in Claude Code."
