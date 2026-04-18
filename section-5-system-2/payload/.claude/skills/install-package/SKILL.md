---
name: install-package
description: Install a NanoClaw capability package received from another operator. Handles manifest reading, dependency resolution, patch application, placeholder substitution, and rollback. Triggers on "install package", "install export", "import capabilities".
---

# Install NanoClaw Capability Package

Orchestrates the installation of a capability export package (`.tar.gz`) received from another NanoClaw operator. Runs entirely inside Claude Code. Each step completes fully before moving to the next.

**Principle:** Ask only questions that cannot be inferred automatically. Never overwrite without showing what changes. Leave the system working or cleanly rolled back.

## Step 0 — Environment Robustness Checks

Before proceeding, verify the environment:

```bash
# Check sqlite3 availability
if command -v sqlite3 &>/dev/null; then
  echo "SQLITE_AVAILABLE=true"
else
  echo "SQLITE_AVAILABLE=false"
  echo "WARNING: sqlite3 not found. Database queries will be skipped."
fi

# Check git availability (required for patches)
command -v git &>/dev/null && echo "GIT_OK=true" || echo "GIT_OK=false — patches cannot be applied"

# Check node version >= 20
NODE_VERSION=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)
if [ -z "$NODE_VERSION" ]; then
  echo "ERROR: node not found"
elif [ "$NODE_VERSION" -lt 20 ]; then
  echo "ERROR: node v$NODE_VERSION found, v20+ required"
else
  echo "NODE_OK=true (v$NODE_VERSION)"
fi

# Check docker availability (non-blocking)
command -v docker &>/dev/null && echo "DOCKER_OK=true" || echo "WARNING: docker not found. Container rebuild will be skipped."
```

Set `SQLITE_AVAILABLE` flag. All subsequent `sqlite3` calls in this skill MUST be guarded:
```bash
if [ "$SQLITE_AVAILABLE" = "true" ]; then
  sqlite3 store/messages.db "..."
fi
```

If node is missing or < v20: stop and tell the operator to install Node.js 20+.
If git is missing: warn that patches cannot be applied but allow continuation for copy-only capabilities.

## Step 1 — Locate the Package

AskUserQuestion: "Where is the extracted package folder? (relative or absolute path, e.g. ~/Downloads/nanoclaw-export-20260322/)"

When the operator provides a path:

```bash
ls "$PATH/package-manifest.json" 2>/dev/null
```

If not found, auto-detect:
```bash
find . -maxdepth 2 -name "package-manifest.json" 2>/dev/null | head -3
```

If found: confirm with user — "Found at: [path]. Is this correct?"
If not found: tell the user to extract first:
```
The file package-manifest.json was not found.
Extract the archive first: tar -xzf nanoclaw-export-*.tar.gz
Then re-run /install-package
```
Stop.

Set `PACKAGE_DIR` to the confirmed path. All subsequent steps use this path.

## Step 2 — Read and Display the Manifest

Read `$PACKAGE_DIR/package-manifest.json` using python3 (jq may not be available):

```bash
python3 -c "
import json
with open('$PACKAGE_DIR/package-manifest.json') as f:
    m = json.load(f)
print(f'Exported: {m[\"exported_at\"]}')
print(f'Source version: {m[\"nanoclaw_version\"]}')
print(f'Notes: {m.get(\"notes\", \"none\")}')
for cap in m.get('capabilities', []):
    deps = ', '.join(cap.get('depends', [])) or 'none'
    print(f'  - {cap[\"label\"]} v{cap[\"version\"]} (depends: {deps})')
"
```

Display formatted summary:
```
NANOCLAW PACKAGE
-----
Exported : [date]
Source version : [version]

Included capabilities:
  [checkmark] [label] v[version]
    Depends on: [deps or "none"]

Exporter notes:
  "[notes]"
-----
```

Check version compatibility:
```bash
THEIR_VERSION=$(git describe --tags --always 2>/dev/null || echo "unknown")
```
If versions differ: display warning (non-blocking):
"This package was created with NanoClaw [package_version]. Your version: [their_version]. Installation may require minor adjustments."

AskUserQuestion: "Continue installation?"

## Step 3 — Check Already-Installed Capabilities

For each capability in `install_order` from the manifest, check if it is already installed by looking for its primary directories (scripts, skills):

```bash
# Example check for a capability with scripts: ["scripts/observability/"]
test -d "scripts/observability/" && echo "ALREADY_INSTALLED" || echo "TO_INSTALL"
```

Display current state:
```
CURRENT STATE
[checkmark] observability -- already installed (will be updated if different)
[empty] control-plane -- will be installed
```

If any capabilities are already installed, AskUserQuestion:
- "Skip existing capabilities (recommended)" — preserve existing files
- "Reinstall everything" — overwrite existing files
- "Choose per capability" — ask for each

Store choice as `REINSTALL_MODE` (skip / overwrite / ask).

## Step 4 — Collect All Configuration

Before touching any file, collect ALL configuration values interactively. No interruptions during file writing.

### 4a — Capability-specific questions
For each capability being installed, read its `config_questions` array from the manifest. Ask each question using AskUserQuestion with the prompt text from the manifest. Store answers keyed by `config_question.id`.

### 4a.1 — Collect env vars per capability
For each capability being installed, read its `env_keys` array from the manifest. Each entry has: `name`, `description`, `required` (bool), `example` (hint), `sensitive` (bool).

For each env_key:
- Use AskUserQuestion with prompt: "[description] (required: [yes/no], example: [example])"
- For sensitive keys (e.g. API keys, tokens): note that the input should not be echoed and will be shown as `****` in the confirmation summary
- Store all answers as `env_values` keyed by `env_key.name`

### 4b — Main group detection
```bash
if [ "$SQLITE_AVAILABLE" = "true" ]; then
  sqlite3 store/messages.db "SELECT folder FROM registered_groups WHERE is_main=1 LIMIT 1" 2>/dev/null
fi
```
If found: confirm with user. If not found: warn that operator access configuration will be deferred.

### 4c — Backup configuration (if observability is being installed)
AskUserQuestion:
- Backup retention count (default: 7)
- Include sessions in backups? (default: no)
- Install daily backup cron at 03:00? (default: yes)

### 4d — Confirmation summary
Display all collected configuration including a "VARIABLES D'ENVIRONNEMENT" section:
```
VARIABLES D'ENVIRONNEMENT
  [capability_name]:
    VAR_NAME: configured [or **** if sensitive]
    VAR_NAME2: [NOT CONFIGURED - required!]
```
Show configured vars with their values (masked as `****` for sensitive keys) and flag any unconfigured required vars.

AskUserQuestion: "Confirm and start installation?"

## Step 5 — Apply Capabilities in Order

Process each capability from `install_order`. Skip if already installed and REINSTALL_MODE is "skip".

**IMPORTANT: Maintain a ROLLBACK_LOG** — before writing any file, if it already exists, copy it to a temp backup location. Record every action for potential rollback.

### 5a — Copy scripts
For each directory in `capability.scripts`:
- Source: `$PACKAGE_DIR/payload/[dir]`
- Target: `[dir]` (same relative path in project)
- If target exists and mode is not overwrite: show diff, ask before overwriting
- After copy: `chmod +x` all `.sh` files

### 5b — Copy Claude Code skills
For each directory in `capability.claude_skills`:
- Same copy pattern as scripts

### 5c — Copy container skills
For each file/dir in `capability.container_skills`:
- Same copy pattern
- Also sync to existing group sessions:
  ```bash
  for dir in data/sessions/*/; do
    cp -r "container/skills/[name]/" "${dir}.claude/skills/[name]/"
  done
  ```

### 5d — Apply src patches
For each `.patch` file in `capability.src_patches`:
```bash
# Dry run first
git apply --3way --check "$PACKAGE_DIR/patches/$patchfile" 2>&1
```
If check passes: apply with `git apply --3way`. Report success.
If check fails: warn about version incompatibility. Show the patch content. Ask user: "Continue without this patch?" If no: trigger rollback (Step 6).

### 5e — Inject global CLAUDE.md sections
For each file in `capability.global_claude_md_sections`:
- Read the section content from `$PACKAGE_DIR/templates/[file]`
- Target: `groups/global/CLAUDE.md`
- Check for existing sentinel: `<!-- CAPABILITY_SECTION_START: [capability_id] -->`
- If exists and mode is skip: leave as-is
- If exists and mode is overwrite: replace content between sentinels
- If not exists: append with sentinels

### 5h — Write env vars to .env

Write collected env vars to the `.env` file:

```bash
# Create .env if it doesn't exist
touch .env
```

For each collected env var:
1. Check if the key already exists in `.env`: `grep -q "^VAR_NAME=" .env`
2. If it exists: show the existing key name (NOT value) and AskUserQuestion: "VAR_NAME already exists in .env. Overwrite?"
3. If overwriting: use `sed` to replace the line
4. If new: append to `.env`

Group new vars by capability with comment headers:
```bash
# --- [capability_name] ---
VAR_NAME=value
VAR_NAME2=value
```

After writing:
- Report what was written (key names only, never values)
- Warn about any unconfigured required vars: "WARNING: [VAR_NAME] is required by [capability] but was not configured. The capability may not work correctly."
- Display: "IMPORTANT: Never commit .env to git. Verify .env is in your .gitignore."

### 5f — Apply templates with placeholder substitution
For each template in `capability.templates`:
- Read from `$PACKAGE_DIR/templates/[file]`
- Replace all `__PLACEHOLDER__` patterns with collected config values:
  - `__OPERATOR_JID__` -> operator JID/ID (or `[CONFIGURE: OPERATOR JID]` if not provided). When collecting this value, show format examples for each channel:
    - WhatsApp: `1234567890@s.whatsapp.net`
    - Telegram: numeric user ID (e.g., `123456789`)
    - Slack: member ID (e.g., `U01ABCDEF`)
    - Discord: user ID (e.g., `123456789012345678`)
  - `__MAIN_FOLDER__` -> main group folder
  - `__BACKUP_KEEP_COUNT__` -> retention count
- Write to the target path specified in the template header or manifest

Report per capability: files copied, patches applied, sections injected.

## Step 6 — Rollback Mechanism

If any step fails and the operator chooses to abort:

```bash
# Reverse all recorded actions
for each entry in ROLLBACK_LOG (reversed):
  if backup exists: restore original file from backup
  if no backup (new file): delete the created file
```

Report: "Rollback complete. No modifications were kept."

The rollback log is an array of entries:
```
{action: "copy"|"patch"|"inject", target: "path", backup: "path or null"}
```

## Step 7 — TypeScript Compilation Check

After all patches applied:
```bash
npm run build 2>&1 | tail -20
```
If errors: show them, ask to continue or rollback.

## Step 8 — Run Verification Tests

If `tests/observability/run-tests.sh` exists:
```bash
bash tests/observability/run-tests.sh
```
Report results. If failures: show which tests failed. Ask to continue or rollback.

## Step 9 — Create Emergency Directory

```bash
if [ "$SQLITE_AVAILABLE" = "true" ]; then
  MAIN_FOLDER=$(sqlite3 store/messages.db "SELECT folder FROM registered_groups WHERE is_main=1 LIMIT 1" 2>/dev/null)
  if [ -n "$MAIN_FOLDER" ]; then
    mkdir -p "groups/$MAIN_FOLDER/emergency"
  fi
fi
```

## Step 10 — Final Report

Display:
```
INSTALLATION COMPLETE
-----
Installed capabilities:
  [checkmark] [label] v[version]

Modified files:
  [list of src patches applied]
  [list of CLAUDE.md sections injected]

Environment variables:
  [checkmark] VAR_NAME — written to .env
  [warning] VAR_NAME — required but not configured
  [info] VAR_NAME — already existed, kept

[if operator JID was skipped:]
  Warning: Operator JID not configured
  -> Edit groups/[main_folder]/CLAUDE.md
  -> Replace [CONFIGURE: OPERATOR JID]

[if backup schedule requested:]
  Note: Start a conversation with your main agent and say:
  "Schedule a daily backup at 3am"

NEXT STEPS
-----
1. Build the project: npm run build
2. Restart NanoClaw
3. Test: send /observe from your operator channel
4. Emergency test: send /! from your operator channel

CHEAT SHEET
-----
/observe              — full status
/observe groups       — groups
/observe tasks        — active tasks
/observe tasks [id]   — task history
/observe agenda       — 7-day calendar
/observe alerts       — anomalies
/observe logs [group] — recent logs

/!                    — emergency status
/! pause [group|all]  — suspend
/! resume [group|all] — resume
/! drain              — maintenance mode
/! undrain            — lift maintenance
/! kill [name|all]    — stop containers
/! lockdown           — lock everything
/! unlock             — unlock everything
```

## Rollback Limits

The rollback mechanism:
- Restores files that were overwritten (from temp backups)
- Deletes files that were newly created
- Does NOT undo `git apply` patches automatically — if a patch was applied and rollback is needed, use `git checkout -- [file]` to restore
- Does NOT undo SQLite changes (e.g., cron job setup)
- Does NOT undo `chmod` changes (harmless)

If rollback is triggered after a patch was applied, explicitly tell the user:
```bash
git checkout -- src/container-runner.ts src/group-queue.ts
```
