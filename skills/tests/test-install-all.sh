#!/usr/bin/env bash
set -euo pipefail
PASS=0; FAIL=0

TMPSKILLS=$(mktemp -d)
trap 'rm -rf "$TMPSKILLS"' EXIT

# Two fake skills with installers that touch a marker file
mkdir -p "$TMPSKILLS/skill-a"
cat > "$TMPSKILLS/skill-a/claude-install.sh" << 'INSTALLER'
#!/usr/bin/env bash
touch "$(dirname "$0")/installed"
INSTALLER
chmod +x "$TMPSKILLS/skill-a/claude-install.sh"

mkdir -p "$TMPSKILLS/skill-b"
cat > "$TMPSKILLS/skill-b/claude-install.sh" << 'INSTALLER'
#!/usr/bin/env bash
touch "$(dirname "$0")/installed"
INSTALLER
chmod +x "$TMPSKILLS/skill-b/claude-install.sh"

# skill-c has no installer — must be silently skipped
mkdir -p "$TMPSKILLS/skill-c"

# Run the top-level installer, pointing it at the temp dir via env var
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/claude-install.sh"
SKILLS_DIR="$TMPSKILLS" bash "$SCRIPT"

# Assertions
if [[ -f "$TMPSKILLS/skill-a/installed" ]]; then
  echo "PASS: skill-a installer was called"; ((PASS++))
else
  echo "FAIL: skill-a installer was not called"; ((FAIL++))
fi

if [[ -f "$TMPSKILLS/skill-b/installed" ]]; then
  echo "PASS: skill-b installer was called"; ((PASS++))
else
  echo "FAIL: skill-b installer was not called"; ((FAIL++))
fi

if [[ ! -f "$TMPSKILLS/skill-c/installed" ]]; then
  echo "PASS: skill-c (no installer) was correctly skipped"; ((PASS++))
else
  echo "FAIL: skill-c was called despite having no installer"; ((FAIL++))
fi

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
