#!/usr/bin/env bash
set -euo pipefail

# registry.sh — Scan the project and output a JSON capability registry to stdout.
# Detects observability, control-plane, and standalone container skills.
#
# Capability schema fields:
#   env_keys       — list of environment variable names the capability requires (e.g. ["API_KEY"]).
#                    Empty [] means no env vars needed (or not yet audited).
#   config_questions — interactive prompts shown during install. Each entry has:
#                    { key: str, prompt: str, required: bool }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Collect capabilities as lines: id|label|version|depends|scripts|claude_skills|container_skills|src_files|config_questions
# We'll feed them to python3 for JSON assembly.

capabilities=()

# 1. Observability capability
if [[ -d "$PROJECT_ROOT/scripts/observability" ]]; then
    obs_version="1.0.0"
    # Try to read version from skill-manifest.yaml if it exists
    if [[ -f "$PROJECT_ROOT/skill-manifest.yaml" ]]; then
        obs_version=$(python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    text = f.read()
m = re.search(r'version:\s*[\"\\']?([^\"\\'\n]+)', text)
if m:
    print(m.group(1).strip())
else:
    print('1.0.0')
" "$PROJECT_ROOT/skill-manifest.yaml")
    fi

    capabilities+=("$(python3 -c "
import json, sys
cap = {
    'id': 'observability',
    'label': 'Observability & Backup Suite',
    'version': sys.argv[1],
    'depends': [],
    'exportable_paths': {
        'scripts': ['scripts/observability/'],
        'claude_skills': ['observe', 'backup', 'backup-list', 'backup-verify', 'restore', 'add-observability'],
        'container_skills': ['container/skills/observability/'],
        'src_files': ['src/container-runner.ts']
    },
    'env_keys': [],
    'config_questions': [
        {
            'key': 'operator_jid',
            'prompt': 'Operator JID for admin access (e.g. 1234567890@s.whatsapp.net)',
            'required': True
        }
    ]
}
print(json.dumps(cap))
" "$obs_version")")
fi

# 2. Control-plane capability (depends on observability)
if [[ -d "$PROJECT_ROOT/scripts/observability/emergency" ]]; then
    capabilities+=("$(python3 -c "
import json
cap = {
    'id': 'control-plane',
    'label': 'Emergency Control Plane',
    'version': '1.0.0',
    'depends': ['observability'],
    'exportable_paths': {
        'scripts': ['scripts/observability/emergency/'],
        'claude_skills': ['emergency'],
        'container_skills': [],
        'src_files': ['src/group-queue.ts']
    },
    'env_keys': [],
    'config_questions': []
}
print(json.dumps(cap))
")")
fi

# 3. Multi-project system capability
if [[ -d "$PROJECT_ROOT/container/skills/multi-project" ]]; then
    capabilities+=("$(python3 -c "
import json
cap = {
    'id': 'multi-project',
    'label': 'Multi-Project Management System',
    'version': '1.0.0',
    'depends': [],
    'exportable_paths': {
        'scripts': [],
        'claude_skills': [],
        'container_skills': ['container/skills/multi-project/'],
        'src_files': ['container/agent-runner/src/index.ts']
    },
    'env_keys': [],
    'config_questions': [
        {
            'key': 'target_group',
            'prompt': 'Which group folder should have the multi-project system? (e.g. whatsapp_personal)',
            'required': True
        }
    ]
}
print(json.dumps(cap))
")")
fi

# 4. Standalone container skills
#    Scan container/skills/ for directories that are not part of core or already registered
CORE_CONTAINER_SKILLS=("observability" "agent-browser" "status" "capabilities" "multi-project")

if [[ -d "$PROJECT_ROOT/container/skills" ]]; then
    for skill_dir in "$PROJECT_ROOT/container/skills"/*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"

        # Skip core skills
        skip=false
        for core in "${CORE_CONTAINER_SKILLS[@]}"; do
            if [[ "$skill_name" == "$core" ]]; then
                skip=true
                break
            fi
        done
        $skip && continue

        # Read metadata from SKILL.md front-matter if present
        capabilities+=("$(python3 -c "
import json, sys, os

skill_name = sys.argv[1]
skill_dir = sys.argv[2]
label = ' '.join(w.capitalize() for w in skill_name.split('-'))

# Parse env_keys from YAML front-matter
env_keys = []
skill_md = os.path.join(skill_dir, 'SKILL.md')
if os.path.isfile(skill_md):
    content = open(skill_md).read()
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            front = parts[1]
            # Read label from name/description
            for line in front.split('\n'):
                stripped = line.strip()
                if stripped.startswith('description:'):
                    label = stripped.split(':',1)[1].strip()
            # Parse env_keys list
            in_env = False
            current = {}
            for line in front.split('\n'):
                stripped = line.strip()
                if stripped == 'env_keys:':
                    in_env = True
                    continue
                if in_env:
                    if stripped.startswith('- name:'):
                        if current: env_keys.append(current)
                        current = {'name': stripped.split(':',1)[1].strip()}
                    elif ':' in stripped and current:
                        k, v = stripped.split(':',1)
                        k = k.strip()
                        v = v.strip().strip('\"')
                        if k in ('description','required','example','sensitive'):
                            if v in ('true','false'): v = v == 'true'
                            current[k] = v
                    elif not stripped.startswith('-') and not stripped.startswith(' ') and stripped:
                        in_env = False
            if current: env_keys.append(current)

cap = {
    'id': skill_name,
    'label': label,
    'version': '1.0.0',
    'depends': [],
    'exportable_paths': {
        'scripts': [],
        'claude_skills': [],
        'container_skills': ['container/skills/' + skill_name + '/'],
        'src_files': []
    },
    'env_keys': env_keys,
    'config_questions': []
}
print(json.dumps(cap))
" "$skill_name" "$skill_dir")")
    done
fi

# Pass 3: Discover unrecognized container skills not caught by Pass 1/2
# These get flagged with needs_env_audit for manual review.
INFRASTRUCTURE=("agent-browser" "capabilities" "status" "observability" "pdf-reader")
DETECTED_IDS=()
for cap_json in "${capabilities[@]}"; do
    cap_id=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['id'])" "$cap_json")
    DETECTED_IDS+=("$cap_id")
done

if [[ -d "$PROJECT_ROOT/container/skills" ]]; then
    for skill_dir in "$PROJECT_ROOT/container/skills"/*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"

        # Skip infrastructure skills
        skip=false
        for infra in "${INFRASTRUCTURE[@]}"; do
            if [[ "$skill_name" == "$infra" ]]; then
                skip=true
                break
            fi
        done
        $skip && continue

        # Skip already-detected capabilities
        for detected in "${DETECTED_IDS[@]}"; do
            if [[ "$skill_name" == "$detected" ]]; then
                skip=true
                break
            fi
        done
        $skip && continue

        # Read label from SKILL.md (first heading or first non-empty line)
        skill_label=""
        if [[ -f "$skill_dir/SKILL.md" ]]; then
            skill_label=$(python3 -c "
import sys
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        # Strip leading '#' for markdown headings
        if line.startswith('#'):
            line = line.lstrip('#').strip()
        print(line)
        break
" "$skill_dir/SKILL.md")
        fi

        # Read env_keys from SKILL.md front-matter (YAML between --- markers) if present
        skill_env_keys=""
        if [[ -f "$skill_dir/SKILL.md" ]]; then
            skill_env_keys=$(python3 -c "
import sys, json
content = open(sys.argv[1]).read()
if not content.startswith('---'):
    print('[]')
    sys.exit()
parts = content.split('---', 2)
if len(parts) < 3:
    print('[]')
    sys.exit()
front = parts[1]
# Simple YAML list parser for env_keys
in_env = False
keys = []
current = {}
for line in front.split('\n'):
    stripped = line.strip()
    if stripped == 'env_keys:':
        in_env = True
        continue
    if in_env:
        if stripped.startswith('- name:'):
            if current: keys.append(current)
            current = {'name': stripped.split(':',1)[1].strip()}
        elif ':' in stripped and current:
            k, v = stripped.split(':',1)
            k = k.strip()
            v = v.strip().strip('\"')
            if k in ('description','required','example','sensitive'):
                if v in ('true','false'): v = v == 'true'
                current[k] = v
        elif not stripped.startswith('-') and not stripped.startswith(' ') and stripped:
            in_env = False
if current: keys.append(current)
print(json.dumps(keys))
" "$skill_dir/SKILL.md")
        fi
        HAS_ENV_KEYS=false
        [[ "$skill_env_keys" != "[]" && -n "$skill_env_keys" ]] && HAS_ENV_KEYS=true

        capabilities+=("$(python3 -c "
import json, sys
skill_name = sys.argv[1]
label = sys.argv[2] if sys.argv[2] else ' '.join(w.capitalize() for w in skill_name.split('-'))
env_keys = json.loads(sys.argv[3]) if sys.argv[3] else []
cap = {
    'id': skill_name,
    'label': label,
    'version': '1.0.0',
    'depends': [],
    'exportable_paths': {
        'scripts': [],
        'claude_skills': [],
        'container_skills': ['container/skills/' + skill_name + '/'],
        'src_files': []
    },
    'env_keys': env_keys,
    'config_questions': [],
    'needs_env_audit': len(env_keys) == 0
}
print(json.dumps(cap))
" "$skill_name" "$skill_label" "$skill_env_keys")")
    done
fi

# Assemble into dependency-sorted JSON array
printf '%s\n' "${capabilities[@]}" | python3 -c "
import json, sys

caps = [json.loads(line) for line in sys.stdin if line.strip()]

# Topological sort: capabilities with no deps first
sorted_caps = []
remaining = list(caps)
resolved_ids = set()

max_iterations = len(remaining) + 1
iteration = 0
while remaining and iteration < max_iterations:
    iteration += 1
    next_remaining = []
    for cap in remaining:
        deps = set(cap.get('depends', []))
        if deps.issubset(resolved_ids):
            sorted_caps.append(cap)
            resolved_ids.add(cap['id'])
        else:
            next_remaining.append(cap)
    remaining = next_remaining

# Append any unresolved (circular deps) at end with warning
for cap in remaining:
    cap['_warning'] = 'unresolved dependencies'
    sorted_caps.append(cap)

print(json.dumps(sorted_caps, indent=2))
"
