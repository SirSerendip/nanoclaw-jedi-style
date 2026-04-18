#!/usr/bin/env bash
set -euo pipefail

# assemble.sh — Assemble an export package from a manifest.
# Usage: assemble.sh MANIFEST_JSON OUTPUT_DIR
#
# MANIFEST_JSON is a file path to a JSON file describing capabilities to export.
# OUTPUT_DIR is where patches/templates may already exist.
# Creates a tar.gz in exports/ with all payload files.
#
# Capability schema fields:
#   env_keys       — list of environment variable names the capability requires (e.g. ["API_KEY"]).
#                    Empty [] means no env vars needed (or not yet audited).
#   config_questions — interactive prompts shown during install. Each entry has:
#                    { key: str, prompt: str, required: bool }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 MANIFEST_JSON OUTPUT_DIR" >&2
    exit 1
fi

MANIFEST_JSON="$1"
OUTPUT_DIR="$2"

if [[ ! -f "$MANIFEST_JSON" ]]; then
    echo "Manifest file not found: $MANIFEST_JSON" >&2
    exit 1
fi

# --- Never include these paths ---
EXCLUDE_PATTERNS=(
    ".env"
    "store/"
    "data/"
    "node_modules/"
    "dist/"
    "backups/"
    "groups/*/CLAUDE.md"
)

# 1. Create staging directory with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
STAGING_DIR="$OUTPUT_DIR/staging-$TIMESTAMP"
mkdir -p "$STAGING_DIR"

echo "Assembling package in $STAGING_DIR ..." >&2

# 2. Parse manifest and copy payload dirs
python3 - "$MANIFEST_JSON" "$STAGING_DIR" "$PROJECT_ROOT" << PYEOF
import json
import sys
import os
import shutil

manifest_path = sys.argv[1]
staging = sys.argv[2]
project = sys.argv[3]

with open(manifest_path) as f:
    manifest = json.load(f)

capabilities = manifest if isinstance(manifest, list) else manifest.get('capabilities', [manifest])

for cap in capabilities:
    paths = cap.get('exportable_paths', {})

    # Copy scripts
    for script_path in paths.get('scripts', []):
        src = os.path.join(project, script_path)
        dst = os.path.join(staging, 'payload', script_path)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        elif os.path.isfile(src):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)

    # Copy claude_skills
    for skill_name in paths.get('claude_skills', []):
        src = os.path.join(project, '.claude', 'skills', skill_name)
        dst = os.path.join(staging, 'payload', '.claude', 'skills', skill_name)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)

    # Copy container_skills
    for skill_path in paths.get('container_skills', []):
        src = os.path.join(project, skill_path)
        dst = os.path.join(staging, 'payload', skill_path)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        elif os.path.isfile(src):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)

    # Copy src_files (as-is for reference, patches go separately)
    for src_file in paths.get('src_files', []):
        src = os.path.join(project, src_file)
        dst = os.path.join(staging, 'payload', 'src_ref', os.path.basename(src_file))
        if os.path.isfile(src):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)

print("Payload copied.", file=sys.stderr)
PYEOF

# 3. Copy patches and templates from OUTPUT_DIR (if any)
if [[ -d "$OUTPUT_DIR" ]]; then
    for item in "$OUTPUT_DIR"/*.patch "$OUTPUT_DIR"/*.fullfile "$OUTPUT_DIR"/*.template; do
        [[ -f "$item" ]] || continue
        mkdir -p "$STAGING_DIR/patches"
        cp "$item" "$STAGING_DIR/patches/"
    done
fi

# 4. Always include install-package skill
INSTALL_PKG_DIR="$PROJECT_ROOT/.claude/skills/install-package"
if [[ -d "$INSTALL_PKG_DIR" ]]; then
    mkdir -p "$STAGING_DIR/payload/.claude/skills/install-package"
    cp -r "$INSTALL_PKG_DIR"/. "$STAGING_DIR/payload/.claude/skills/install-package/"
fi

# 4b. Always include export infrastructure — recipients can re-export
EXPORT_SKILL_DIR="$PROJECT_ROOT/.claude/skills/export"
EXPORT_SCRIPTS_DIR="$PROJECT_ROOT/scripts/export"
if [[ -d "$EXPORT_SKILL_DIR" ]]; then
    mkdir -p "$STAGING_DIR/payload/.claude/skills/export"
    cp -r "$EXPORT_SKILL_DIR"/. "$STAGING_DIR/payload/.claude/skills/export/"
fi
if [[ -d "$EXPORT_SCRIPTS_DIR" ]]; then
    mkdir -p "$STAGING_DIR/payload/scripts/export"
    cp -r "$EXPORT_SCRIPTS_DIR"/. "$STAGING_DIR/payload/scripts/export/"
fi

# 5. Always include INSTALL.md and install-bootstrap.sh if they exist
for bootstrap_file in INSTALL.md install-bootstrap.sh; do
    if [[ -f "$PROJECT_ROOT/$bootstrap_file" ]]; then
        cp "$PROJECT_ROOT/$bootstrap_file" "$STAGING_DIR/"
    fi
done

# 6. Get version info for manifest
NANOCLAW_VERSION=$(cd "$PROJECT_ROOT" && git describe --tags --always 2>/dev/null || echo "unknown")

# 7. Write package-manifest.json
python3 - "$MANIFEST_JSON" "$STAGING_DIR" "$TIMESTAMP" "$NANOCLAW_VERSION" << PYEOF
import json
import sys
import os

manifest_path = sys.argv[1]
staging = sys.argv[2]
timestamp = sys.argv[3]
nanoclaw_version = sys.argv[4]

with open(manifest_path) as f:
    manifest = json.load(f)

package_manifest = {
    'format_version': '1.0',
    'exported_at': timestamp,
    'nanoclaw_version': nanoclaw_version,
    'notes': manifest.get('notes', None) if isinstance(manifest, dict) else None,
    'capabilities': manifest if isinstance(manifest, list) else manifest.get('capabilities', [manifest])
}

output_path = os.path.join(staging, 'package-manifest.json')
with open(output_path, 'w') as f:
    json.dump(package_manifest, f, indent=2)

print("package-manifest.json written.", file=sys.stderr)
PYEOF

# 8. Compute SHA256 checksums
(
    cd "$STAGING_DIR"
    find . -type f ! -name 'SHA256SUMS' -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)
echo "Checksums computed." >&2

# 8b. Security scan — block forbidden files from package
FORBIDDEN_PATTERNS=(".env" "messages.db" "creds.json" "auth/" "sessions/" "data/env" "backups/" "*.tar.gz")
SECURITY_FAIL=0
for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
  FOUND=$(find "$STAGING_DIR" -name "$pattern" -o -path "*/$pattern" 2>/dev/null | head -5)
  if [ -n "$FOUND" ]; then
    echo "SECURITY: Forbidden file detected: $FOUND" >&2
    SECURITY_FAIL=1
  fi
done
if [ "$SECURITY_FAIL" -eq 1 ]; then
  echo "Assembly blocked by security scan." >&2
  rm -rf "$STAGING_DIR"
  exit 1
fi
echo "Security scan: clean" >&2

# 9. Create tar.gz in exports/
# (steps renumbered after security scan insertion)
EXPORTS_DIR="$PROJECT_ROOT/exports"
mkdir -p "$EXPORTS_DIR"

ARCHIVE_NAME="nanoclaw-export-$TIMESTAMP.tar.gz"
ARCHIVE_PATH="$EXPORTS_DIR/$ARCHIVE_NAME"

# Build exclude args for tar
TAR_EXCLUDES=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    TAR_EXCLUDES+=(--exclude="$pattern")
done

tar czf "$ARCHIVE_PATH" -C "$(dirname "$STAGING_DIR")" "${TAR_EXCLUDES[@]}" "$(basename "$STAGING_DIR")"

echo "Archive created: $ARCHIVE_PATH" >&2

# 10. Verify archive
if tar tzf "$ARCHIVE_PATH" > /dev/null 2>&1; then
    ARCHIVE_SIZE=$(stat --format=%s "$ARCHIVE_PATH" 2>/dev/null || stat -f%z "$ARCHIVE_PATH" 2>/dev/null || echo "unknown")
    FILE_COUNT=$(tar tzf "$ARCHIVE_PATH" | wc -l)
    echo "Archive verified: $FILE_COUNT entries, $ARCHIVE_SIZE bytes." >&2
else
    echo "ERROR: Archive verification failed!" >&2
    exit 1
fi

# 11. Output summary JSON
echo "Auto-included: /install-package, /export skills" >&2
python3 -c "
import json
summary = {
    'status': 'ok',
    'archive': '$ARCHIVE_PATH',
    'staging_dir': '$STAGING_DIR',
    'archive_size': '$ARCHIVE_SIZE',
    'file_count': $FILE_COUNT,
    'timestamp': '$TIMESTAMP'
}
print(json.dumps(summary, indent=2))
"
