#!/bin/bash
set -euo pipefail

# init.sh — Initialize the multi-project system in the current group
# Run once per group. Safe to re-run (idempotent checks).

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROUP_DIR="/workspace/group"
PROJECTS_DIR="$GROUP_DIR/projects"
DB="$PROJECTS_DIR/memory.db"

echo "=== Multi-Project System Setup ==="
echo ""

# 1. Create projects directory
mkdir -p "$PROJECTS_DIR"

# 2. Copy project.sh
if [ -f "$PROJECTS_DIR/project.sh" ]; then
  echo "project.sh already exists — skipping (delete manually to replace)"
else
  cp "$SKILL_DIR/project.sh" "$PROJECTS_DIR/project.sh"
  chmod +x "$PROJECTS_DIR/project.sh"
  echo "Installed: project.sh"
fi

# 3. Create database from schema
if [ -f "$DB" ]; then
  echo "memory.db already exists — skipping (delete manually to recreate)"
else
  sqlite3 "$DB" < "$SKILL_DIR/schema.sql"
  echo "Created: memory.db (schema v4)"
fi

# 4. Copy .gitignore
if [ -f "$GROUP_DIR/.gitignore" ]; then
  echo ".gitignore already exists — skipping"
else
  cp "$SKILL_DIR/.gitignore.template" "$GROUP_DIR/.gitignore"
  echo "Installed: .gitignore"
fi

# 5. Inject CLAUDE.md System 1
if grep -q "MULTI_PROJECT_SYSTEM_START" "$GROUP_DIR/CLAUDE.md" 2>/dev/null; then
  echo "CLAUDE.md already has multi-project section — skipping"
else
  # Append with a blank line separator
  echo "" >> "$GROUP_DIR/CLAUDE.md" 2>/dev/null || touch "$GROUP_DIR/CLAUDE.md"
  cat "$SKILL_DIR/claude-md.template" >> "$GROUP_DIR/CLAUDE.md"
  echo "Injected: System 1 reflexes into CLAUDE.md"
fi

# 6. Initialize git for checkpoints (optional but recommended)
if [ -d "$GROUP_DIR/.git" ]; then
  echo "Git already initialized — skipping"
else
  cd "$GROUP_DIR"
  git init -q
  git config user.name "nanoclaw"
  git config user.email "nanoclaw@local"
  echo "Initialized: git repository"
fi

# 7. First SQL dump + initial commit
sqlite3 "$DB" .dump > "$PROJECTS_DIR/memory.sql" 2>/dev/null || true
cd "$GROUP_DIR"
git add -A
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -q -m "multi-project system initialized"
  echo "Created: initial git checkpoint"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Create your first project:"
echo "  project.sh init my-project \"My Project Name\""
echo ""
echo "Quick reference:"
echo "  project.sh list              — all projects"
echo "  project.sh context <slug>    — load project context"
echo "  project.sh switch <from> <to> \"context\" — switch between projects"
echo "  project.sh history           — checkpoint history"
echo "  project.sh --help            — full command list"
