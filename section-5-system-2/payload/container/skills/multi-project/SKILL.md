---
name: multi-project
description: Multi-project management system with session continuity, task tracking, lens personas, and git checkpoints. Use when the user wants to manage multiple projects in a single group with persistent context across sessions.
env_keys: []
---

# Multi-Project Management System

Manage multiple projects in a single NanoClaw group with full session continuity. Each project has its own context, tasks, specs, decisions, and STATUS.md. Switching between projects preserves state via SQLite + git checkpoints.

## First-time setup

Run once to initialize the system in this group:

```bash
bash /home/node/.claude/skills/multi-project/init.sh
```

This creates:
- `projects/project.sh` — CLI for all project operations
- `projects/memory.db` — SQLite database (projects, tasks, specs, decisions, memory, agents)
- `projects/memory.sql` — Diffable text dump of the DB
- `.gitignore` — Configured for git checkpoint (excludes binaries, includes text)
- Git repository — For automatic pre-compaction checkpoints
- CLAUDE.md injection — System 1 behavioral reflexes

## Core workflow

```bash
# Create a project
project.sh init my-project "My Project Name"

# Load project context (at session start)
project.sh context my-project

# Work on the project...

# End session (required before switching)
project.sh session-end my-project

# Switch to another project
project.sh switch my-project other-project "what I was doing" "summary"
```

## Commands

| Command | Purpose |
|---|---|
| `init <slug> "Name"` | Create a new project |
| `list` | Show all projects with status |
| `context <slug>` | Load full project context |
| `switch <from> <to> "ctx" ["sum"]` | Pause one project, activate another |
| `session-end <slug>` | Record session, check STATUS.md freshness |
| `done <slug> <task-id>` | Mark a task as completed |
| `status-scan <slug>` | List files changed since STATUS.md |
| `history [log\|diff\|show\|recover\|db]` | Navigate git checkpoint history |
| `git-checkpoint ["msg"]` | Manual checkpoint (auto on compaction) |
| `context-size <slug>` | Estimate token cost of context injection |
| `specs <slug>` | List specifications |
| `tasks <slug>` | List tasks |
| `decisions <slug>` | List decisions |
| `stats` | Global stats across all projects |

## Lens system

Add agent personas that activate automatically per project:

```sql
-- Add an agent lens
INSERT INTO agents (slug, lens, prompt)
VALUES ('strategist', 'analytical', 'You are a strategic analyst...');

-- Assign to a project
UPDATE projects SET required_lenses = 'strategist' WHERE slug = 'my-project';
```

The lens prompt is automatically injected when loading context or switching to that project.

## Git checkpoints

At every SDK compaction (PreCompact hook), the system automatically:
1. Archives the conversation to `conversations/`
2. Dumps `memory.db` to `memory.sql` (diffable text)
3. Commits all workspace changes (`git commit`)
4. Writes a re-injection marker so context is reloaded post-compaction

Navigate history: `project.sh history log`, `project.sh history diff`, `project.sh history db`.

## PreCompact hook requirement

For automatic git checkpoints and post-compaction re-injection, the container agent-runner needs modifications. These are included as a source patch during export. If the patch cannot be applied:
- Git checkpoints won't fire automatically (but `project.sh git-checkpoint` works manually)
- Post-compaction re-injection won't happen (but `project.sh context <slug>` works manually)
- The system degrades gracefully — all core features work without the hook
