#!/usr/bin/env bash
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find NanoClaw project root
if [ -f "./package.json" ] && grep -q "nanoclaw" "./package.json" 2>/dev/null; then
  NANOCLAW_ROOT="$(pwd)"
elif [ -n "${NANOCLAW_ROOT:-}" ]; then
  echo "Using NANOCLAW_ROOT=$NANOCLAW_ROOT"
else
  echo "Run this script from your NanoClaw project root"
  echo "or set NANOCLAW_ROOT=/path/to/nanoclaw"
  exit 1
fi

# Copy the install skill
mkdir -p "$NANOCLAW_ROOT/.claude/skills/install-package"
cp "$PACKAGE_DIR/.claude/skills/install-package/SKILL.md" \
   "$NANOCLAW_ROOT/.claude/skills/install-package/SKILL.md"

echo "Install skill copied."
echo ""
echo "Now, from your Claude Code session in the NanoClaw project:"
echo "  /install-package $PACKAGE_DIR"
