# Meta-System — SYSTEM.md
> How the multi-project system works. Reference doc for agents and humans.

---

## Overview

The meta-system governs the workspace infrastructure. It is not a product — it's the system that manages all other projects. Changes here propagate everywhere.

## Core Loop

```
Session Start → project.sh context <slug> → load state + lens
    ↓
Work (specs, tasks, code, decisions)
    ↓
Session End → project.sh session-end <slug>
    ↓
Switch → project.sh switch <from> <to> "context"
    ↓
Git Checkpoint → project.sh git-checkpoint "message"
```

## project.sh Commands

| Command | Purpose |
|---------|---------|
| `init <slug> "Name"` | Create project + management dir |
| `list` | All projects + status |
| `context <slug>` | Full session context + STATUS.md + lens |
| `context-size <slug>` | Token cost estimate |
| `switch <from> <to> "ctx"` | Pause from, activate to (with guards) |
| `session-end <slug>` | Snapshot + status-scan + record |
| `set-context <slug> "ctx"` | Update working_context |
| `status-scan <slug>` | Files changed since STATUS.md |
| `sync <slug>` | Sync files into documents table |
| `git-checkpoint ["msg"]` | Dump DB + git commit |
| `history [sub]` | Navigate checkpoints (log/diff/show/recover/db/files) |
| `specs <slug> [status]` | List specs |
| `tasks <slug> [spec] [status]` | List tasks |
| `decisions <slug>` | Active decisions |
| `stats` | Global stats |
| `done <slug> <task-id>` | Mark task done |

## Memory Rules

1. *DB_WRITE_RULE* — Structured state in memory.db tables, not loose files
2. *STATUS_MD_PROTOCOL* — STATUS.md derived from code, updated every pause
3. *SCAN_BEFORE_REPORT* — Always scan workspace before reporting
4. *CONTEXT_LOAD_HOOK* — Reload context on session start
5. *PAUSE_PROTOCOL* — status-scan → STATUS.md → switch (blocked if stale)

## Lenses

Lenses are agent personas auto-injected by `project.sh context` when a project has `required_lenses` set. The `agents` table stores slug, lens type, and system prompt.

## Git Checkpoints

- Repo at `/workspace/group/`
- `memory.db` excluded from git (binary) — dumped to `memory.sql` before commit
- `.needs-context-reload` excluded
- `project.sh git-checkpoint` handles the full cycle
- `project.sh history` navigates the log
