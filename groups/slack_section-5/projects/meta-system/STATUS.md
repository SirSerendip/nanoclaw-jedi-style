# Meta-System — STATUS
> Source de vérité. Mis à jour à chaque pause. Dérivé du code, pas de la mémoire.
> Last updated: 2026-04-10 | Version: v4 (schema)

---

## ARCHITECTURE

| Component | File/Path | Role |
|---|---|---|
| project.sh | `/workspace/group/projects/project.sh` | Central orchestrator — all project commands |
| memory.db | `/workspace/group/projects/memory.db` | SQLite DB — projects, specs, tasks, decisions, memory, agents, sessions, documents |
| CLAUDE.md | `/workspace/group/CLAUDE.md` | System 1 reflexes — auto-loaded every session |
| .gitignore | `/workspace/group/.gitignore` | Excludes memory.db, .needs-context-reload, binaries |
| sqlite3 shim | `/home/node/bin/sqlite3` | Node.js wrapper (better-sqlite3) — no native sqlite3 in container |

---

## DB SCHEMA (v4)

| Table | Purpose |
|---|---|
| projects | Project registry (slug, name, status, working_context, required_lenses) |
| sessions | Session log (project_id, date, type, summary, key_outputs) |
| specs | Feature specs (project_id, title, status, priority) |
| tasks | Task tracking (project_id, spec_id, title, status, priority) |
| decisions | Decision log (project_id, title, decision, rationale, status) |
| documents | File registry (project_id, path, type, title) |
| memory | Persistent memory (project_id, type, content, always_load) |
| agents | Lens agents (slug, lens type, prompt) |

---

## PROTOCOLS — STATE

| Protocol | Status | Notes |
|---|---|---|
| STATUS_MD_PROTOCOL | active | Source of truth per project |
| PAUSE_PROTOCOL | active | status-scan → update STATUS.md → switch |
| CONTEXT_LOAD_HOOK | active | Auto-reload on session start |
| DB_WRITE_RULE | active | Structured state in DB, not loose files |
| SCAN_BEFORE_REPORT | active | Always scan before reporting |
| META_SYSTEM_ROLE | active | This project governs the system |

---

## LENSES

| Slug | Type | Role |
|---|---|---|
| ludor | systemic | Metacognitive — observes, debugs, evolves the system |

---

## REGISTERED PROJECTS

| Slug | Status |
|---|---|
| deepagents | paused |
| meta-system | active |

---

## KNOWN DEBT

| Item | Severity | Detail |
|---|---|---|
| sqlite3 shim | ✅ | Node.js better-sqlite3 wrapper at `/home/node/bin/sqlite3` — works, needs PATH export per session |
| Pre-compact hook | 📋 | Needs NanoClaw update + Claude Code wiring to trigger `project.sh git-checkpoint` on context compaction |
