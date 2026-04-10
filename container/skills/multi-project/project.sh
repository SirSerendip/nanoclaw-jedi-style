#!/bin/bash
# project.sh — Ludor project memory utility
# Schema v4 | Hierarchy: Project → Spec → Task | Priorities: now/next/later
DB="/workspace/group/projects/memory.db"
PROJECTS_ROOT="/workspace/group/projects"
MEMORY_DIR="/home/node/.claude/projects/-workspace-group/memory"

# --- INTERNAL: write pause summary to memory file + update MEMORY.md index ---
# Called automatically by switch. Ensures DB pause state is visible at next session start.
_write_memory_pause() {
  local SLUG="$1"
  local CONTEXT="$2"
  local SUMMARY="$3"
  local DATE
  DATE=$(date +%Y-%m-%d)
  local MEMORY_FILE="$MEMORY_DIR/${SLUG}_pause_summary.md"

  local PROJ_NAME
  PROJ_NAME=$(sqlite3 "$DB" "SELECT name FROM projects WHERE slug='$SLUG';")

  local OPEN_TASKS
  OPEN_TASKS=$(sqlite3 "$DB" "
    SELECT '- ' || t.priority || ' | ' || t.title
    FROM tasks t
    WHERE t.project_id=(SELECT id FROM projects WHERE slug='$SLUG')
      AND t.status='open'
    ORDER BY CASE t.priority WHEN 'now' THEN 1 WHEN 'next' THEN 2 WHEN 'later' THEN 3 END
    LIMIT 8;
  ")

  mkdir -p "$MEMORY_DIR"

  cat > "$MEMORY_FILE" <<EOF
---
name: ${PROJ_NAME} — pause summary
description: ${PROJ_NAME} paused (${DATE}) — Resume Here context
type: project
---

Paused: ${DATE}

*Resume Here:* ${CONTEXT}

*Why / Summary:* ${SUMMARY:-—}

---

## Open Tasks

${OPEN_TASKS:-(none)}
EOF

  # Update MEMORY.md index: replace existing line or append
  local INDEX="$MEMORY_DIR/MEMORY.md"
  local SHORT_CTX
  SHORT_CTX=$(echo "$CONTEXT" | head -c 80)
  local NEW_LINE="- [${SLUG}_pause_summary.md](${SLUG}_pause_summary.md) — ${PROJ_NAME} paused (${DATE}): ${SHORT_CTX}"

  if [ -f "$INDEX" ] && grep -q "${SLUG}_pause_summary\.md" "$INDEX"; then
    # Replace in-place (POSIX-safe temp file)
    local TMP
    TMP=$(mktemp)
    grep -v "${SLUG}_pause_summary\.md" "$INDEX" > "$TMP"
    echo "$NEW_LINE" >> "$TMP"
    mv "$TMP" "$INDEX"
  else
    echo "$NEW_LINE" >> "$INDEX"
  fi

  echo "✓ Memory file updated: ${SLUG}_pause_summary.md"
}

# --- INTERNAL: sync project files into documents table ---
_sync_docs() {
  local SLUG="$1"
  local PROJ_DIR="$PROJECTS_ROOT/$SLUG"
  [ -d "$PROJ_DIR" ] || return
  find "$PROJ_DIR" -type f \
    ! -path "*/node_modules/*" \
    ! -path "*/.git/*" \
    ! -name "*.pyc" \
    ! -name ".DS_Store" \
  | while read -r filepath; do
    local relpath="${filepath#$PROJ_DIR/}"
    local ext="${filepath##*.}"
    sqlite3 "$DB" "
      INSERT INTO documents (project_id, path, type, title, created_at, updated_at)
      SELECT p.id, '$relpath', '$ext', '$relpath', datetime('now'), datetime('now')
      FROM projects p WHERE p.slug='$SLUG'
      AND NOT EXISTS (
        SELECT 1 FROM documents d
        JOIN projects p2 ON d.project_id=p2.id
        WHERE p2.slug='$SLUG' AND d.path='$relpath'
      );
    "
  done
  echo "Documents synced for '$SLUG'."
}

case "$1" in

  # --- LIST PROJECTS ---
  list)
    echo "=== PROJECTS ==="
    sqlite3 "$DB" "SELECT slug, name, status, last_session_at FROM projects ORDER BY status, last_session_at DESC;"
    ;;

  # --- SESSION CONTEXT (load at session start) ---
  context)
    PROJECT="$2"
    if [ -z "$PROJECT" ]; then echo "Usage: project.sh context <slug>"; exit 1; fi
    echo "=== WHERE WE LEFT OFF ==="
    sqlite3 "$DB" "SELECT working_context FROM projects WHERE slug='$PROJECT' AND working_context IS NOT NULL;"
    echo ""
    echo "=== PAUSE SUMMARY ==="
    sqlite3 "$DB" "SELECT pause_summary FROM projects WHERE slug='$PROJECT' AND pause_summary IS NOT NULL;"
    echo ""
    echo "=== MEMORY (always_load) ==="
    sqlite3 "$DB" "SELECT type, content FROM memory WHERE project_id=(SELECT id FROM projects WHERE slug='$PROJECT') AND always_load=1 ORDER BY importance DESC;"
    echo ""
    echo "=== ACTIVE SPECS ==="
    sqlite3 "$DB" "SELECT priority, title, status FROM specs WHERE project_id=(SELECT id FROM projects WHERE slug='$PROJECT') AND status IN ('draft','active') ORDER BY priority, created_at;"
    echo ""
    echo "=== OPEN TASKS ==="
    sqlite3 "$DB" "
      SELECT t.priority, t.title, COALESCE(s.title, '-') as spec
      FROM tasks t LEFT JOIN specs s ON t.spec_id=s.id
      WHERE t.project_id=(SELECT id FROM projects WHERE slug='$PROJECT')
        AND t.status='open'
      ORDER BY CASE t.priority WHEN 'now' THEN 1 WHEN 'next' THEN 2 WHEN 'later' THEN 3 END, t.created_at;
    "
    echo ""
    echo "=== ACTIVE DECISIONS ==="
    sqlite3 "$DB" "SELECT title, decision FROM decisions WHERE project_id=(SELECT id FROM projects WHERE slug='$PROJECT') AND status='active' ORDER BY date DESC LIMIT 5;"
    echo ""
    echo "=== STATUS.md (technical truth) ==="
    PROJ_DIR="$PROJECTS_ROOT/$PROJECT"
    STATUS_FILE=$(find "$PROJ_DIR" -maxdepth 3 -name "STATUS.md" 2>/dev/null | head -1)
    if [ -n "$STATUS_FILE" ]; then
      echo "(source: $STATUS_FILE)"
      cat "$STATUS_FILE"
    else
      echo "⚠  No STATUS.md found — run: project.sh status-scan $PROJECT"
    fi
    echo ""
    echo "=== PROJECT FILES ==="
    if [ -d "$PROJ_DIR" ]; then
      if command -v tree &>/dev/null; then
        tree "$PROJ_DIR" --noreport -I "node_modules|.git|*.pyc|.DS_Store"
      else
        find "$PROJ_DIR" -type f ! -path "*/node_modules/*" ! -path "*/.git/*" | sort
      fi
    else
      echo "(no project directory at $PROJ_DIR)"
    fi

    # Auto-inject required lenses for this project
    REQUIRED_LENSES=$(sqlite3 "$DB" "SELECT required_lenses FROM projects WHERE slug='$PROJECT';")
    if [ -n "$REQUIRED_LENSES" ]; then
      echo ""
      echo "=== LENS ACTIF ==="
      IFS=',' read -ra LENS_SLUGS <<< "$REQUIRED_LENSES"
      for LENS_SLUG in "${LENS_SLUGS[@]}"; do
        LENS_SLUG=$(echo "$LENS_SLUG" | xargs)
        LENS_PROMPT=$(sqlite3 "$DB" "SELECT prompt FROM agents WHERE slug='$LENS_SLUG';")
        if [ -n "$LENS_PROMPT" ]; then
          echo "--- $LENS_SLUG ---"
          echo "$LENS_PROMPT"
        fi
      done
      echo "=== END LENS ==="
    fi
    ;;

  # --- SWITCH PROJECT (pause current, activate new, sync docs) ---
  switch)
    FROM="$2"
    TO="$3"
    WORKING="$4"
    if [ -z "$FROM" ] || [ -z "$TO" ] || [ -z "$WORKING" ]; then
      echo "Usage: project.sh switch <from-slug> <to-slug> \"working_context\" [\"pause_summary\"] [--lens <slug1>...] [--force] [--dry-run]"
      exit 1
    fi

    # Parse SUMMARY (optional positional) and flags from remaining args
    SUMMARY=""
    LENSES=()
    FORCE=""
    DRY_RUN=""
    shift 4
    while [ $# -gt 0 ]; do
      case "$1" in
        --lens) shift; LENSES+=("$1") ;;
        --force) FORCE="--force" ;;
        --dry-run) DRY_RUN="1" ;;
        *) [ -z "$SUMMARY" ] && SUMMARY="$1" ;;
      esac
      shift
    done

    # Guard: session-end must have been run today for FROM project (skip for dry-run)
    if [ -z "$DRY_RUN" ]; then
      LAST_SESSION_DATE=$(sqlite3 "$DB" "
        SELECT s.date FROM sessions s
        JOIN projects p ON s.project_id = p.id
        WHERE p.slug='$FROM'
        ORDER BY s.date DESC LIMIT 1;
      ")
      TODAY=$(date +%Y-%m-%d)
      if [ "$LAST_SESSION_DATE" != "$TODAY" ] && [ "$FORCE" != "--force" ]; then
        echo "⚠  session-end non execute aujourd'hui pour '$FROM'."
        echo "   Executez d'abord : project.sh session-end $FROM"
        echo "   Ou utilisez --force pour ignorer."
        exit 1
      fi
    fi

    # Guard: warn if STATUS.md missing or stale (>7 days) for the project being paused
    FROM_DIR="$PROJECTS_ROOT/$FROM"
    STATUS_FILE=$(find "$FROM_DIR" -maxdepth 3 -name "STATUS.md" 2>/dev/null | head -1)
    if [ -z "$STATUS_FILE" ]; then
      echo "⚠  WARNING: No STATUS.md found for '$FROM'."
      echo "   Run: project.sh status-scan $FROM   then update/create STATUS.md before switching."
      echo "   To force switch anyway: add '--force' flag."
      if [ "$FORCE" != "--force" ]; then exit 1; fi
    else
      LAST_MOD=$(stat -c %Y "$STATUS_FILE" 2>/dev/null || stat -f %m "$STATUS_FILE" 2>/dev/null)
      NOW=$(date +%s)
      AGE_DAYS=$(( (NOW - LAST_MOD) / 86400 ))
      if [ "$AGE_DAYS" -gt 7 ]; then
        echo "⚠  WARNING: STATUS.md for '$FROM' is ${AGE_DAYS} days old."
        echo "   Consider running: project.sh status-scan $FROM"
        echo "   Continuing anyway (stale but present)..."
      fi
    fi

    # Dry-run: show what would happen, no mutations
    if [ -n "$DRY_RUN" ]; then
      echo "DRY RUN — aucune modification"
      echo "FROM: $FROM -> status=paused, working_context='$(echo "$WORKING" | head -c 80)'"
      echo "TO:   $TO -> status=active"
      echo "Session: enregistree pour $FROM"
      # Show required lenses for TO project
      REQ_LENSES=$(sqlite3 "$DB" "SELECT required_lenses FROM projects WHERE slug='$TO';")
      [ -n "$REQ_LENSES" ] && echo "Lenses auto: $REQ_LENSES"
      [ ${#LENSES[@]} -gt 0 ] && echo "Lenses manuels: ${LENSES[*]}"
      exit 0
    fi

    # Sync documents for project being paused (file scan — must run before transaction)
    _sync_docs "$FROM"

    # Atomic transaction: pause FROM, record session, activate TO
    if [ -z "$SUMMARY" ]; then
      sqlite3 "$DB" "
        BEGIN;
        UPDATE projects SET status='paused', working_context='$WORKING' WHERE slug='$FROM';
        INSERT INTO sessions (project_id, date, session_type, summary, key_outputs)
          SELECT id, date('now'), 'mixed', 'Session terminee — contexte: $WORKING', ''
          FROM projects WHERE slug='$FROM';
        UPDATE projects SET status='active', last_session_at=datetime('now') WHERE slug='$TO';
        COMMIT;
      "
    else
      sqlite3 "$DB" "
        BEGIN;
        UPDATE projects SET status='paused', working_context='$WORKING', pause_summary='$SUMMARY' WHERE slug='$FROM';
        INSERT INTO sessions (project_id, date, session_type, summary, key_outputs)
          SELECT id, date('now'), 'mixed', 'Session terminee — contexte: $WORKING', '$SUMMARY'
          FROM projects WHERE slug='$FROM';
        UPDATE projects SET status='active', last_session_at=datetime('now') WHERE slug='$TO';
        COMMIT;
      "
    fi
    echo "Paused: '$FROM' | Activated: '$TO'"

    # Auto-write memory file for FROM project (DB → memory/*.md sync)
    _write_memory_pause "$FROM" "$WORKING" "$SUMMARY"

    # Auto-activate required lenses for TO project
    REQUIRED_LENSES=$(sqlite3 "$DB" "SELECT required_lenses FROM projects WHERE slug='$TO';")
    if [ -n "$REQUIRED_LENSES" ]; then
      echo ""
      echo "=== LENS ACTIVATION ==="
      IFS=',' read -ra AUTO_LENS_SLUGS <<< "$REQUIRED_LENSES"
      for LENS_SLUG in "${AUTO_LENS_SLUGS[@]}"; do
        LENS_SLUG=$(echo "$LENS_SLUG" | xargs)
        LENS_PROMPT=$(sqlite3 "$DB" "SELECT prompt FROM agents WHERE slug='$LENS_SLUG';")
        if [ -z "$LENS_PROMPT" ]; then
          echo "⚠  Lens '$LENS_SLUG' introuvable dans agents — ignore."
        else
          echo "--- Lens: $LENS_SLUG ---"
          echo "$LENS_PROMPT"
          echo ""
        fi
      done
      echo "=== END LENS ACTIVATION ==="
    fi

    # Load additional explicit lenses (--lens flag, additive)
    if [ ${#LENSES[@]} -gt 0 ]; then
      echo ""
      echo "=== LENS LOAD (explicit) ==="
      for LENS_SLUG in "${LENSES[@]}"; do
        LENS_PROMPT=$(sqlite3 "$DB" "SELECT prompt FROM agents WHERE slug='$LENS_SLUG';")
        if [ -z "$LENS_PROMPT" ]; then
          echo "⚠  Lens '$LENS_SLUG' not found in agents table — skipped."
        else
          echo "--- Lens: $LENS_SLUG ---"
          echo "$LENS_PROMPT"
          echo ""
        fi
      done
      echo "=== END LENS LOAD ==="
    fi
    ;;

  # --- SYNC DOCUMENTS ONLY ---
  sync)
    PROJECT="$2"
    if [ -z "$PROJECT" ]; then echo "Usage: project.sh sync <slug>"; exit 1; fi
    _sync_docs "$PROJECT"
    sqlite3 "$DB" "
      SELECT d.path, d.type, d.created_at FROM documents d
      JOIN projects p ON d.project_id=p.id
      WHERE p.slug='$PROJECT'
      ORDER BY d.created_at DESC;
    "
    ;;

  # --- MARK TASK DONE ---
  done)
    PROJECT="$2"
    TASK_ID="$3"
    NOTE="$4"
    if [ -z "$PROJECT" ] || [ -z "$TASK_ID" ]; then
      echo "Usage: project.sh done <slug> <task-id> [\"completion note\"]"
      exit 1
    fi
    sqlite3 "$DB" "
      UPDATE tasks SET status='done', done_at=datetime('now'),
        description=CASE WHEN '$NOTE' != '' THEN description || ' | done: $NOTE' ELSE description END
      WHERE id=$TASK_ID
        AND project_id=(SELECT id FROM projects WHERE slug='$PROJECT');
    "
    echo "Task $TASK_ID marked done."
    ;;

  # --- SESSION END: snapshot + status-scan + ready-to-copy switch command ---
  session-end)
    PROJECT="$2"
    if [ -z "$PROJECT" ]; then echo "Usage: project.sh session-end <slug>"; exit 1; fi
    echo "=== SESSION END — $PROJECT ==="
    echo ""

    echo "--- current working_context ---"
    sqlite3 "$DB" "SELECT working_context FROM projects WHERE slug='$PROJECT';"
    echo ""

    echo "--- tasks changed this session ---"
    sqlite3 "$DB" "
      SELECT status, priority, title FROM tasks
      WHERE project_id=(SELECT id FROM projects WHERE slug='$PROJECT')
        AND (done_at >= datetime('now', '-8 hours') OR created_at >= datetime('now', '-8 hours'))
      ORDER BY CASE status WHEN 'done' THEN 1 ELSE 2 END;
    "
    echo ""

    # Auto status-scan (improvement D)
    PROJ_DIR_SE="$PROJECTS_ROOT/$PROJECT"
    STATUS_FILE_SE=$(find "$PROJ_DIR_SE" -maxdepth 3 -name "STATUS.md" 2>/dev/null | head -1)
    if [ -z "$STATUS_FILE_SE" ]; then
      echo "⚠  STATUS.md MISSING — create before closing session"
    else
      CHANGED_SE=$(find "$PROJ_DIR_SE" -type f -newer "$STATUS_FILE_SE" \
        ! -name "STATUS.md" ! -path "*/node_modules/*" ! -path "*/.git/*" \
        ! -name "*.pyc" ! -name ".DS_Store" 2>/dev/null | sort)
      COUNT_SE=$(echo "$CHANGED_SE" | grep -v '^[[:space:]]*$' | wc -l | tr -d ' ')
      if [ "$COUNT_SE" -gt 0 ]; then
        echo "--- STATUS.md stale — $COUNT_SE file(s) to document ---"
        echo "$CHANGED_SE" | while read -r f; do
          echo "  • ${f#$PROJ_DIR_SE/}"
        done
        echo ""
        echo "  Checklist:"
        echo "  [ ] VIEWS / FEATURES — implementation status accurate?"
        echo "  [ ] ARCHITECTURE — new pattern, file, or layer?"
        echo "  [ ] KNOWN DEBT — resolved or newly introduced?"
        echo "  [ ] DATA FILES — schema changes?"
        echo "  [ ] Version string — bump ?v= if JS/CSS deployed"
      else
        echo "--- STATUS.md up to date ✓ ---"
      fi
    fi
    echo ""

    echo "--- update working_context template ---"
    echo "last_action: ?"
    echo "open_question: ?"
    echo "next_gesture: ?"
    echo "energy: [stuck|progressing|finishing]"
    echo ""
    echo "1. project.sh set-context $PROJECT \"last_action: ... | open_question: ...\""
    echo "2. project.sh switch $PROJECT <next-slug> \"<context>\" \"<summary>\""

    # Record that session-end was called (gate for switch command)
    sqlite3 "$DB" "
      INSERT INTO sessions (project_id, date, session_type, summary, key_outputs)
      SELECT id, date('now'), 'mixed',
             'session-end appele — en attente de switch',
             ''
      FROM projects WHERE slug='$PROJECT';
    "
    echo ""
    echo "Session enregistree pour '$PROJECT' — $(date '+%d/%m a %H:%M')"
    ;;

  # --- SET WORKING CONTEXT directly ---
  set-context)
    PROJECT="$2"
    CONTEXT="$3"
    if [ -z "$PROJECT" ] || [ -z "$CONTEXT" ]; then
      echo "Usage: project.sh set-context <slug> \"key: value lines\""
      exit 1
    fi
    sqlite3 "$DB" "UPDATE projects SET working_context='$CONTEXT' WHERE slug='$PROJECT';"
    echo "working_context updated for '$PROJECT'."
    ;;

  # --- SPECS ---
  specs)
    PROJECT="$2"
    STATUS="${3:-active}"
    sqlite3 "$DB" "
      SELECT s.priority, s.title, s.status,
             (SELECT count(*) FROM tasks t WHERE t.spec_id=s.id AND t.status='open') as open_tasks
      FROM specs s
      WHERE s.project_id=(SELECT id FROM projects WHERE slug='$PROJECT')
        AND s.status='$STATUS'
      ORDER BY s.priority, s.created_at;
    "
    ;;

  # --- TASKS ---
  tasks)
    PROJECT="$2"
    SPEC="$3"
    STATUS="${4:-open}"
    if [ -z "$SPEC" ]; then
      sqlite3 "$DB" "
        SELECT t.priority, t.title, t.status, COALESCE(s.title, '-') as spec
        FROM tasks t LEFT JOIN specs s ON t.spec_id=s.id
        WHERE t.project_id=(SELECT id FROM projects WHERE slug='$PROJECT')
          AND t.status='$STATUS'
        ORDER BY CASE t.priority WHEN 'now' THEN 1 WHEN 'next' THEN 2 WHEN 'later' THEN 3 END, t.created_at;
      "
    else
      sqlite3 "$DB" "
        SELECT t.priority, t.title, t.status
        FROM tasks t
        WHERE t.spec_id=(SELECT id FROM specs WHERE project_id=(SELECT id FROM projects WHERE slug='$PROJECT') AND title LIKE '%$SPEC%' LIMIT 1)
          AND t.status='$STATUS'
        ORDER BY CASE t.priority WHEN 'now' THEN 1 WHEN 'next' THEN 2 WHEN 'later' THEN 3 END, t.created_at;
      "
    fi
    ;;

  # --- DECISIONS ---
  decisions)
    PROJECT="$2"
    sqlite3 "$DB" "SELECT date, type, title, decision FROM decisions WHERE project_id=(SELECT id FROM projects WHERE slug='$PROJECT') AND status='active' ORDER BY date DESC;"
    ;;

  # --- DEPLOY + VERIFY (R1+R2) ---
  # Usage: project.sh deploy-verify <slug> <ftp-remote-dir> file1 [file2 ...]
  # Reads FTP credentials from env, uploads files, verifies each via ftplib LIST.
  deploy-verify)
    PROJECT="$2"
    REMOTE_DIR="$3"
    shift 3
    FILES=("$@")
    if [ -z "$PROJECT" ] || [ -z "$REMOTE_DIR" ] || [ ${#FILES[@]} -eq 0 ]; then
      echo "Usage: project.sh deploy-verify <slug> <remote-dir> file1 [file2 ...]"
      echo "  remote-dir: FTP path e.g. /Projects/SiD/viewer"
      echo "  files: local paths relative to cwd"
      exit 1
    fi

    echo "=== DEPLOY + VERIFY — $PROJECT ==="
    echo "Remote dir : $REMOTE_DIR"
    echo ""

    # STATUS.md staleness check (improvement B — non-blocking warning)
    PROJ_DIR_B="$PROJECTS_ROOT/$PROJECT"
    STATUS_FILE_B=$(find "$PROJ_DIR_B" -maxdepth 3 -name "STATUS.md" 2>/dev/null | head -1)
    if [ -n "$STATUS_FILE_B" ]; then
      STALE_COUNT=$(find "$PROJ_DIR_B" -type f -newer "$STATUS_FILE_B" \
        ! -name "STATUS.md" ! -path "*/node_modules/*" ! -path "*/.git/*" \
        ! -name "*.pyc" ! -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
      if [ "$STALE_COUNT" -gt 0 ]; then
        echo "⚠  STATUS.md stale — $STALE_COUNT file(s) changed since last update"
        echo "   Update STATUS.md after this deploy."
        echo ""
      fi
    fi

    # Deploy root = CWD — user must run deploy-verify from the deployable directory (e.g. sid/viewer/)
    # Files outside CWD are management files (STATUS.md, project.sh, memory.db…) and must not be deployed
    DEPLOY_ROOT=$(pwd)

    FAILED=()
    for LOCAL in "${FILES[@]}"; do
      BASENAME=$(basename "$LOCAL")

      # Guard: file must live inside the deploy root (CWD)
      ABS_LOCAL=$(realpath "$LOCAL" 2>/dev/null || readlink -f "$LOCAL" 2>/dev/null || echo "")
      if [ -n "$ABS_LOCAL" ] && [[ "$ABS_LOCAL" != "$DEPLOY_ROOT/"* ]]; then
        echo "✗ BLOCKED — $LOCAL  (outside deploy root $DEPLOY_ROOT — management file?)"
        FAILED+=("$LOCAL")
        continue
      fi

      # Preserve relative path: partials/settings.php → REMOTE_DIR/partials/settings.php
      LOCAL_REL="${LOCAL#./}"
      REMOTE_PATH="${REMOTE_DIR}/${LOCAL_REL}"
      REMOTE_FILE_DIR=$(dirname "$REMOTE_PATH")

      # Upload
      curl -s -T "$LOCAL" \
        "ftp://${FTP_USER}:${FTP_PASS}@${FTP_HOST}${REMOTE_PATH}"
      CURL_EXIT=$?

      if [ $CURL_EXIT -ne 0 ]; then
        echo "✗ UPLOAD FAILED ($CURL_EXIT) — $LOCAL"
        FAILED+=("$LOCAL")
        continue
      fi

      # Verify via ftplib LIST (date + size) — list the correct remote subdirectory
      LOCAL_SIZE=$(wc -c < "$LOCAL" | tr -d ' ')
      VERIFY=$(python3 -c "
import ftplib, os, sys
ftp = ftplib.FTP()
ftp.connect(os.environ['FTP_HOST'], 21)
ftp.login(os.environ['FTP_USER'], os.environ['FTP_PASS'])
target_dir = '${REMOTE_FILE_DIR}'
target_file = '${BASENAME}'
lines = []
try:
    ftp.retrlines('LIST ' + target_dir, lines.append)
except: pass
ftp.quit()
for line in lines:
    parts = line.split()
    if parts and parts[-1] == target_file:
        size = int(parts[4]) if len(parts) >= 5 else -1
        date = ' '.join(parts[5:8]) if len(parts) >= 8 else '?'
        print(f'FOUND size={size} date={date}')
        sys.exit(0)
print('NOT_FOUND')
sys.exit(1)
" 2>&1)

      if echo "$VERIFY" | grep -q "FOUND"; then
        REMOTE_SIZE=$(echo "$VERIFY" | grep -oP 'size=\K[0-9]+')
        DATE=$(echo "$VERIFY" | grep -oP 'date=\K.*')
        if [ "$REMOTE_SIZE" = "$LOCAL_SIZE" ]; then
          echo "✓ $LOCAL  ($LOCAL_SIZE b, $DATE)"
        else
          echo "⚠ SIZE MISMATCH $LOCAL — local=$LOCAL_SIZE remote=$REMOTE_SIZE"
          FAILED+=("$LOCAL")
        fi
      else
        echo "✗ NOT FOUND ON SERVER — $LOCAL"
        FAILED+=("$LOCAL")
      fi
    done

    echo ""
    if [ ${#FAILED[@]} -eq 0 ]; then
      echo "All files verified on server."
    else
      echo "FAILURES: ${FAILED[*]}"
      exit 1
    fi
    ;;

  # --- STATUS SCAN: analyse files changed since last STATUS.md, guide the update ---
  status-scan)
    PROJECT="$2"
    if [ -z "$PROJECT" ]; then echo "Usage: project.sh status-scan <slug>"; exit 1; fi
    PROJ_DIR="$PROJECTS_ROOT/$PROJECT"
    if [ ! -d "$PROJ_DIR" ]; then echo "No directory at $PROJ_DIR"; exit 1; fi

    echo "=== STATUS SCAN — $PROJECT ==="
    echo ""

    # Locate STATUS.md (search up to 3 levels deep)
    STATUS_FILE=$(find "$PROJ_DIR" -maxdepth 3 -name "STATUS.md" 2>/dev/null | head -1)

    if [ -z "$STATUS_FILE" ]; then
      echo "STATUS.md : ✗ NOT FOUND"
      echo "Action    : Create STATUS.md from scratch (derive from code scan)"
      echo ""
      REFERENCE_TIME=0
    else
      LAST_MOD=$(stat -c %Y "$STATUS_FILE" 2>/dev/null || stat -f %m "$STATUS_FILE" 2>/dev/null)
      LAST_MOD_HUMAN=$(date -d "@$LAST_MOD" "+%Y-%m-%d %H:%M" 2>/dev/null || date -r "$LAST_MOD" "+%Y-%m-%d %H:%M" 2>/dev/null)
      NOW=$(date +%s)
      AGE_DAYS=$(( (NOW - LAST_MOD) / 86400 ))
      echo "STATUS.md : ✓ FOUND at $STATUS_FILE"
      echo "Last update: $LAST_MOD_HUMAN (${AGE_DAYS}d ago)"
      echo ""
      REFERENCE_TIME=$LAST_MOD
    fi

    # Files changed since STATUS.md (or all files if no STATUS.md)
    echo "=== FILES CHANGED SINCE LAST STATUS.md ==="
    CHANGED=$(find "$PROJ_DIR" -type f \
      ! -name "STATUS.md" \
      ! -path "*/node_modules/*" \
      ! -path "*/.git/*" \
      ! -name "*.pyc" \
      ! -name ".DS_Store" \
      -newer "$STATUS_FILE" 2>/dev/null | sort)

    if [ -z "$CHANGED" ]; then
      echo "(no files changed since last STATUS.md)"
    else
      COUNT=$(echo "$CHANGED" | wc -l | tr -d ' ')
      echo "$COUNT file(s) modified:"
      echo "$CHANGED" | while read -r f; do
        RELPATH="${f#$PROJ_DIR/}"
        MOD_DATE=$(stat -c "%y" "$f" 2>/dev/null | cut -d'.' -f1 || stat -f "%Sm" "$f" 2>/dev/null)
        echo "  • $RELPATH  ($MOD_DATE)"
      done
    fi

    echo ""
    echo "=== STATUS.md UPDATE CHECKLIST ==="
    echo "For each changed file above, verify in STATUS.md:"
    echo "  [ ] VIEWS / FEATURES table — is implementation status accurate?"
    echo "  [ ] ARCHITECTURE table — any new pattern, file, or layer added?"
    echo "  [ ] KNOWN DEBT table — anything resolved or newly introduced?"
    echo "  [ ] DATA FILES — any new seed files or schema changes?"
    echo "  [ ] Version string (if applicable) — bump if JS/CSS deployed"
    echo ""
    echo "After updating STATUS.md, run: project.sh switch $PROJECT <next-slug> \"<context>\" \"<summary>\""
    ;;

  # --- INIT NEW PROJECT ---
  # Usage: project.sh init <slug> <"Full Name"> [deploy-subdir]
  # Creates: DB entry + management dir + skeleton STATUS.md (outside deploy dir)
  init)
    SLUG="$2"
    NAME="$3"
    DEPLOY_SUB="${4:-}"   # optional: e.g. "viewer" or "ftp" — documented in STATUS.md
    if [ -z "$SLUG" ] || [ -z "$NAME" ]; then
      echo "Usage: project.sh init <slug> \"Full Name\" [deploy-subdir]"
      echo "  deploy-subdir: optional subdirectory that will be the FTP/deploy root (e.g. viewer, ftp)"
      exit 1
    fi

    # Check slug not already taken
    EXISTS=$(sqlite3 "$DB" "SELECT count(*) FROM projects WHERE slug='$SLUG';")
    if [ "$EXISTS" -gt 0 ]; then
      echo "✗ Project '$SLUG' already exists."
      exit 1
    fi

    # Create management directory
    PROJ_DIR="$PROJECTS_ROOT/$SLUG"
    mkdir -p "$PROJ_DIR"

    # Insert into DB
    sqlite3 "$DB" "
      INSERT INTO projects (slug, name, status, created_at, last_session_at)
      VALUES ('$SLUG', '$NAME', 'active', datetime('now'), datetime('now'));
    "

    # Create skeleton STATUS.md at management root (NOT in deploy subdir)
    DEPLOY_NOTE=""
    [ -n "$DEPLOY_SUB" ] && DEPLOY_NOTE="Deploy root : \$PROJECTS_ROOT/$SLUG/$DEPLOY_SUB/ (management files stay at $SLUG/)"
    cat > "$PROJ_DIR/STATUS.md" <<EOF
# $NAME — STATUS
> Source de vérité. Mis à jour à chaque pause. Dérivé du code, pas de la mémoire.
> Last updated: $(date +%Y-%m-%d) | Version: —
$([ -n "$DEPLOY_SUB" ] && echo "> $DEPLOY_NOTE")

---

## ARCHITECTURE

| Composant | Fichier/Dossier | Rôle |
|---|---|---|
| — | — | — |

---

## FEATURES — ÉTAT

| Feature | Statut | Notes |
|---|---|---|
| — | — | — |

---

## KNOWN DEBT

| Item | Sévérité | Détail |
|---|---|---|
| STATUS.md à compléter | ⚠️ | Créé au init — à enrichir après premier scan |

---

## DATA FILES

| Fichier | Rôle | État |
|---|---|---|
| — | — | — |
EOF

    echo "✓ Project '$SLUG' initialized."
    echo "  DB entry    : created (status=active)"
    echo "  Mgmt dir    : $PROJ_DIR/"
    echo "  STATUS.md   : $PROJ_DIR/STATUS.md  ← management only, never deploy"
    [ -n "$DEPLOY_SUB" ] && echo "  Deploy root : $PROJ_DIR/$DEPLOY_SUB/  ← run deploy-verify from here"
    echo ""
    echo "Next: project.sh context $SLUG"
    ;;

  # --- GIT CHECKPOINT: dump DB + commit workspace state ---
  git-checkpoint)
    if [ ! -d "/workspace/group/.git" ]; then
      echo "No .git in /workspace/group — run git init first"
      exit 0
    fi

    # Dump memory.db to diffable SQL text (memory.db itself is gitignored)
    if [ -f "$DB" ]; then
      sqlite3 "$DB" .dump > "$PROJECTS_ROOT/memory.sql" 2>/dev/null || true
    fi

    cd /workspace/group
    git add -A
    # Commit only if there are staged changes
    if ! git diff --cached --quiet 2>/dev/null; then
      MSG="${2:-checkpoint: precompact $(date -u +%Y%m%dT%H%M%SZ)}"
      git commit -q -m "$MSG"
      echo "Checkpoint committed: $MSG"
    else
      echo "Nothing changed since last checkpoint."
    fi
    ;;

  # --- HISTORY: navigate git checkpoint history ---
  history)
    if [ ! -d "/workspace/group/.git" ]; then
      echo "No .git in /workspace/group — no checkpoint history available"
      exit 0
    fi

    SUB="${2:-log}"
    case "$SUB" in

      # project.sh history — recent checkpoints
      log)
        echo "=== CHECKPOINT HISTORY ==="
        git -C /workspace/group log --oneline --date=short \
          --format="%h %ad %s" -15
        ;;

      # project.sh history diff [N] — what changed since last (or between N-1 and N)
      diff)
        N="${3:-1}"
        echo "=== DIFF: HEAD~$N → HEAD ==="
        git -C /workspace/group diff --stat "HEAD~$N" HEAD 2>/dev/null || \
          echo "Not enough checkpoints for diff ~$N"
        ;;

      # project.sh history show <file> [N] — file content at checkpoint N (default: last)
      show)
        FILE="$3"
        REV="${4:-HEAD}"
        if [ -z "$FILE" ]; then
          echo "Usage: project.sh history show <file> [HEAD~N]"
          exit 1
        fi
        git -C /workspace/group show "$REV:$FILE" 2>/dev/null || \
          echo "File '$FILE' not found at revision $REV"
        ;;

      # project.sh history recover <file> [N] — restore file from checkpoint
      recover)
        FILE="$3"
        REV="${4:-HEAD}"
        if [ -z "$FILE" ]; then
          echo "Usage: project.sh history recover <file> [HEAD~N]"
          exit 1
        fi
        if ! git -C /workspace/group show "$REV:$FILE" >/dev/null 2>&1; then
          echo "File '$FILE' not found at revision $REV"
          exit 1
        fi
        git -C /workspace/group show "$REV:$FILE" > "/workspace/group/$FILE"
        echo "Recovered: $FILE (from $REV)"
        ;;

      # project.sh history db [N] — diff of memory.sql between checkpoints
      db)
        N="${3:-1}"
        echo "=== DB CHANGES: HEAD~$N → HEAD ==="
        git -C /workspace/group diff "HEAD~$N" HEAD -- projects/memory.sql 2>/dev/null || \
          echo "Not enough checkpoints or no memory.sql changes"
        ;;

      # project.sh history files [N] — list files changed between checkpoints
      files)
        N="${3:-1}"
        echo "=== FILES CHANGED: HEAD~$N → HEAD ==="
        git -C /workspace/group diff --name-only "HEAD~$N" HEAD 2>/dev/null || \
          echo "Not enough checkpoints for diff ~$N"
        ;;

      *)
        echo "Usage: project.sh history [log|diff|show|recover|db|files] [args]"
        echo ""
        echo "  log                  — recent checkpoints (default)"
        echo "  diff [N]             — what changed in last N checkpoints (default: 1)"
        echo "  show <file> [REV]    — file content at a checkpoint (default: HEAD)"
        echo "  recover <file> [REV] — restore a file from a checkpoint"
        echo "  db [N]               — memory.sql diff between checkpoints"
        echo "  files [N]            — list files changed between checkpoints"
        ;;
    esac
    ;;

  # --- CONTEXT SIZE: estimate token cost of context injection ---
  context-size)
    PROJECT="$2"
    if [ -z "$PROJECT" ]; then echo "Usage: project.sh context-size <slug>"; exit 1; fi
    CTX_OUTPUT=$(bash "$0" context "$PROJECT" 2>/dev/null)
    CTX_CHARS=$(echo "$CTX_OUTPUT" | wc -c | tr -d ' ')
    CTX_LINES=$(echo "$CTX_OUTPUT" | wc -l | tr -d ' ')
    CTX_TOKENS=$(( CTX_CHARS / 4 ))

    LENS_CHARS=0
    REQ_LENSES=$(sqlite3 "$DB" "SELECT required_lenses FROM projects WHERE slug='$PROJECT';")
    if [ -n "$REQ_LENSES" ]; then
      IFS=',' read -ra LS_ARRAY <<< "$REQ_LENSES"
      for LS in "${LS_ARRAY[@]}"; do
        LS=$(echo "$LS" | xargs)
        LC=$(sqlite3 "$DB" "SELECT length(prompt) FROM agents WHERE slug='$LS';" 2>/dev/null)
        LENS_CHARS=$(( LENS_CHARS + ${LC:-0} ))
      done
    fi
    LENS_TOKENS=$(( LENS_CHARS / 4 ))
    TOTAL=$(( CTX_TOKENS + LENS_TOKENS ))

    echo "Context injection cost for '$PROJECT':"
    echo "  Project context : ~${CTX_TOKENS} tokens (${CTX_LINES} lines)"
    echo "  Lens(es)        : ~${LENS_TOKENS} tokens"
    echo "  Total injection : ~${TOTAL} tokens"
    echo ""
    echo "CLAUDE.md (fixed) : ~1580 tokens"
    echo "Grand total       : ~$(( TOTAL + 1580 )) tokens"
    ;;

  # --- GLOBAL STATS ---
  stats)
    echo "=== GLOBAL STATS ==="
    sqlite3 "$DB" "
      SELECT p.name, p.status,
             (SELECT count(*) FROM specs s WHERE s.project_id=p.id AND s.status IN ('draft','active')) as specs,
             (SELECT count(*) FROM tasks t WHERE t.project_id=p.id AND t.status='open') as open_tasks,
             (SELECT count(*) FROM tasks t WHERE t.project_id=p.id AND t.status='done') as done_tasks,
             (SELECT count(*) FROM decisions d WHERE d.project_id=p.id AND d.status='active') as decisions,
             (SELECT count(*) FROM documents d WHERE d.project_id=p.id) as docs
      FROM projects p ORDER BY p.status, p.last_session_at DESC;
    "
    ;;

  *)
    echo "Usage: project.sh <command> [args]"
    echo ""
    echo "  init <slug> \"Name\" [deploy-subdir]         — create project + management dir + skeleton STATUS.md"
    echo "  list                                      — all projects + status"
    echo "  context <slug>                            — full session context + STATUS.md + file tree + lens"
    echo "  context-size <slug>                       — estimated token cost of context injection"
    echo "  git-checkpoint [\"message\"]                — dump DB + git commit workspace (PreCompact hook)"
    echo "  history [log|diff|show|recover|db|files]  — navigate checkpoint history"
    echo "  status-scan <slug>                        — files changed since STATUS.md + update checklist"
    echo "  switch <from> <to> \"ctx\" [\"sum\"] [flags]  — pause from, activate to (guards: session-end, STATUS.md)"
    echo "    flags: --lens <slug> --force --dry-run"
    echo "  sync <slug>                               — sync project files into documents table"
    echo "  done <slug> <task-id> [\"note\"]            — mark task done with optional note"
    echo "  session-end <slug>                        — snapshot + status-scan + record session"
    echo "  set-context <slug> \"context\"             — update working_context directly"
    echo "  deploy-verify <slug> <remote-dir> files…  — upload + verify via ftplib LIST"
    echo "  stats                                     — global stats across all projects"
    echo ""
    echo "  specs <slug> [status]                     — specs (default: active)"
    echo "  tasks <slug> [spec] [status]              — tasks (default: open)"
    echo "  decisions <slug>                          — active decisions"
    echo ""
    echo "PAUSE PROTOCOL:"
    echo "  1. project.sh status-scan <slug>          — identify what changed"
    echo "  2. Update/create STATUS.md in project dir — derive from code, not memory"
    echo "  3. project.sh switch <from> <to> ...      — blocked if STATUS.md missing"
    ;;
esac
