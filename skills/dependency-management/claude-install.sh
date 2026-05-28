#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$HOME/.claude/skills/dependency-management"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing dependency-management skill to $SKILL_DIR..."
mkdir -p "$SKILL_DIR/scripts"
cp "$SOURCE_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
cp "$SOURCE_DIR/manual-runbook.md" "$SKILL_DIR/manual-runbook.md"
cp "$SOURCE_DIR/scripts/"*.sh "$SKILL_DIR/scripts/"
chmod +x "$SKILL_DIR/scripts/"*.sh
echo "Done. Invoke with /dependency-management in Claude Code."
