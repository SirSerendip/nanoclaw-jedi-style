#!/usr/bin/env bash
set -euo pipefail

# generate-patches.sh — Generate git patches for src/ files of a capability.
# Usage: generate-patches.sh CAPABILITY_ID OUTPUT_DIR
#
# Reads the capability registry to find src_files, then creates patches
# against upstream/main. Falls back to full-file copy if patch fails.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 CAPABILITY_ID OUTPUT_DIR" >&2
    exit 1
fi

CAPABILITY_ID="$1"
OUTPUT_DIR="$2"

mkdir -p "$OUTPUT_DIR"

# Get the registry and extract src_files for this capability
SRC_FILES=$(bash "$PROJECT_ROOT/scripts/export/registry.sh" | python3 -c "
import json, sys
caps = json.load(sys.stdin)
for cap in caps:
    if cap['id'] == sys.argv[1]:
        for f in cap.get('exportable_paths', {}).get('src_files', []):
            print(f)
        break
" "$CAPABILITY_ID")

if [[ -z "$SRC_FILES" ]]; then
    echo "No src_files found for capability '$CAPABILITY_ID'" >&2
    python3 -c "import json; print(json.dumps({'capability': '$CAPABILITY_ID', 'patches': [], 'status': 'no_src_files'}))"
    exit 0
fi

cd "$PROJECT_ROOT"

# Determine base ref for diffing
BASE_REF=""
if git rev-parse --verify upstream/main >/dev/null 2>&1; then
    BASE_REF="upstream/main"
elif git rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE_REF="origin/main"
else
    # Try to find a reasonable base from git log
    BASE_REF=$(git log --oneline --all --max-count=50 2>/dev/null | tail -1 | awk '{print $1}') || true
fi

patches=()

while IFS= read -r src_file; do
    [[ -z "$src_file" ]] && continue

    # Convert path to safe filename
    safe_name=$(echo "$src_file" | sed 's|/|_|g; s|\.|-|g')
    patch_file="$OUTPUT_DIR/${safe_name}.patch"
    status="ok"
    method="diff"
    warning=""

    if [[ -n "$BASE_REF" ]]; then
        # Try generating a diff patch
        if git diff "$BASE_REF" -- "$src_file" > "$patch_file.tmp" 2>/dev/null; then
            if [[ -s "$patch_file.tmp" ]]; then
                # Validate the patch
                if git apply --check "$patch_file.tmp" 2>/dev/null; then
                    mv "$patch_file.tmp" "$patch_file"
                else
                    # Patch doesn't apply cleanly — could be already applied or conflicts
                    # Try reverse check (patch already applied)
                    if git apply --check --reverse "$patch_file.tmp" 2>/dev/null; then
                        mv "$patch_file.tmp" "$patch_file"
                        warning="patch already applied on current tree"
                    else
                        # Fall back to full file
                        rm -f "$patch_file.tmp"
                        if [[ -f "$src_file" ]]; then
                            cp "$src_file" "$patch_file.fullfile"
                            patch_file="$patch_file.fullfile"
                            method="full_file"
                            warning="patch validation failed; included full file as fallback"
                        else
                            status="missing"
                            warning="file not found: $src_file"
                        fi
                    fi
                fi
            else
                # Empty diff — no changes from upstream
                rm -f "$patch_file.tmp"
                status="unchanged"
                method="none"
                warning="no diff from $BASE_REF"
                patch_file=""
            fi
        else
            # git diff failed — file may not exist in base
            rm -f "$patch_file.tmp"
            if [[ -f "$src_file" ]]; then
                cp "$src_file" "$patch_file.fullfile"
                patch_file="$patch_file.fullfile"
                method="full_file"
                warning="no upstream version found; included full file"
            else
                status="missing"
                warning="file not found: $src_file"
                patch_file=""
            fi
        fi
    else
        # No base ref at all — full file fallback
        if [[ -f "$src_file" ]]; then
            cp "$src_file" "$patch_file.fullfile"
            patch_file="$patch_file.fullfile"
            method="full_file"
            warning="no base ref available; included full file as fallback"
        else
            status="missing"
            warning="file not found and no base ref"
            patch_file=""
        fi
    fi

    patches+=("$(python3 -c "
import json, sys
entry = {
    'src_file': sys.argv[1],
    'patch_file': sys.argv[2],
    'method': sys.argv[3],
    'status': sys.argv[4],
    'base_ref': sys.argv[5]
}
if sys.argv[6]:
    entry['warning'] = sys.argv[6]
print(json.dumps(entry))
" "$src_file" "${patch_file:-}" "$method" "$status" "${BASE_REF:-none}" "$warning")")

done <<< "$SRC_FILES"

# Output JSON summary
printf '%s\n' "${patches[@]}" | python3 -c "
import json, sys
patches = [json.loads(line) for line in sys.stdin if line.strip()]
summary = {
    'capability': '$CAPABILITY_ID',
    'base_ref': '${BASE_REF:-none}',
    'output_dir': '$OUTPUT_DIR',
    'patches': patches
}
print(json.dumps(summary, indent=2))
"
