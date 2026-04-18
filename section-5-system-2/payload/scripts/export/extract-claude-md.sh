#!/usr/bin/env bash
set -euo pipefail

# extract-claude-md.sh — Extract, analyze, and sanitize CLAUDE.md sections.
# Usage: extract-claude-md.sh [--sections IDS] [--sanitize] SOURCE_FILE OUTPUT_FILE
#
# Modes:
#   No flags:            Output analysis JSON of all sections (personal/exportable classification)
#   --sections ID1,ID2:  Extract only sentinel-marked sections by ID
#   --sanitize:          Remove personal info from output

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SECTIONS=""
SANITIZE=false
SOURCE_FILE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sections)
            SECTIONS="$2"
            shift 2
            ;;
        --sanitize)
            SANITIZE=true
            shift
            ;;
        *)
            if [[ -z "$SOURCE_FILE" ]]; then
                SOURCE_FILE="$1"
            elif [[ -z "$OUTPUT_FILE" ]]; then
                OUTPUT_FILE="$1"
            else
                echo "Unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$SOURCE_FILE" ]]; then
    echo "Usage: $0 [--sections IDS] [--sanitize] SOURCE_FILE OUTPUT_FILE" >&2
    exit 1
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Source file not found: $SOURCE_FILE" >&2
    exit 1
fi

# --- Python helper for all heavy lifting ---
python3 << 'PYEOF' "$SOURCE_FILE" "${OUTPUT_FILE:-}" "$SECTIONS" "$SANITIZE"
import re
import json
import sys

source_file = sys.argv[1]
output_file = sys.argv[2] if sys.argv[2] else None
sections_arg = sys.argv[3]  # comma-separated IDs or empty
sanitize = sys.argv[4] == "true"

with open(source_file, "r", encoding="utf-8") as f:
    content = f.read()


def extract_sentinel_sections(text):
    """Find content between <!-- CAPABILITY_SECTION_START: X --> markers."""
    pattern = r'<!--\s*CAPABILITY_SECTION_START:\s*(\S+)\s*-->(.*?)<!--\s*CAPABILITY_SECTION_END:\s*\1\s*-->'
    matches = re.findall(pattern, text, re.DOTALL)
    return {section_id: body.strip() for section_id, body in matches}


def extract_all_sections(text):
    """Split by H2 headers (## ...), return list with index, preview, content."""
    # Split on H2 headers, keeping the header
    parts = re.split(r'(?=^## )', text, flags=re.MULTILINE)
    sections = []
    idx = 0
    for part in parts:
        part = part.strip()
        if not part:
            continue
        # Extract header line for preview
        lines = part.split('\n')
        header = lines[0].strip() if lines else ''
        preview = header[:80] if header else part[:80]
        sections.append({
            'index': idx,
            'header': header,
            'preview': preview,
            'content': part
        })
        idx += 1
    return sections


def classify_section(section_content):
    """Classify a section as personal or exportable."""
    personal_patterns = [
        r'\d{10,15}@s\.whatsapp\.net',  # WhatsApp JIDs
        r'\+?\d{10,15}',                 # Phone numbers
        r'(?i)\b(je suis|mon |ma |mes |notre )\b',  # French first-person
        r'(?i)\b(i am|my |our )\b',       # English first-person possessives
        r'(?i)\b(hamid|personal)\b',       # Personal name markers
        r'@[a-zA-Z0-9]+\.(gmail|yahoo|hotmail)\.',  # Email-like patterns
    ]
    score = 0
    for pat in personal_patterns:
        if re.search(pat, section_content):
            score += 1
    return 'personal' if score >= 2 else 'exportable'


def sanitize_section(text):
    """Remove personal info: phone numbers, JIDs, personal references."""
    # Replace WhatsApp JIDs with placeholder
    text = re.sub(r'\d{10,15}@s\.whatsapp\.net', '__OPERATOR_JID__', text)
    # Replace phone numbers (10+ digits, optional + prefix)
    text = re.sub(r'\+?\d{10,15}', '__PHONE__', text)
    # Remove first-person French references
    text = re.sub(r'(?i)\b(je suis|j\'ai|mon |ma |mes |notre )\S*', '[REDACTED]', text)
    # Remove personal name markers
    text = re.sub(r'(?i)\bhamid\b', '__OPERATOR__', text)
    return text


def wrap_in_sentinel(section_id, content):
    """Wrap content in standard sentinel comments."""
    return (
        f"<!-- CAPABILITY_SECTION_START: {section_id} -->\n"
        f"{content}\n"
        f"<!-- CAPABILITY_SECTION_END: {section_id} -->"
    )


# --- Main logic ---

if sections_arg:
    # Mode: extract specific sentinel sections
    requested_ids = [s.strip() for s in sections_arg.split(',')]
    sentinel_sections = extract_sentinel_sections(content)

    extracted_parts = []
    for sid in requested_ids:
        if sid in sentinel_sections:
            body = sentinel_sections[sid]
            if sanitize:
                body = sanitize_section(body)
            extracted_parts.append(wrap_in_sentinel(sid, body))
        else:
            print(f"Warning: section '{sid}' not found in {source_file}", file=sys.stderr)

    result = '\n\n'.join(extracted_parts)

    if output_file:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(result + '\n')
        print(json.dumps({
            'status': 'ok',
            'source': source_file,
            'output': output_file,
            'sections_extracted': [s for s in requested_ids if s in sentinel_sections],
            'sections_missing': [s for s in requested_ids if s not in sentinel_sections],
            'sanitized': sanitize
        }, indent=2))
    else:
        print(result)

elif output_file:
    # Mode: extract all content with optional sanitization
    result = content
    if sanitize:
        result = sanitize_section(result)

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(result)
    print(json.dumps({
        'status': 'ok',
        'source': source_file,
        'output': output_file,
        'sanitized': sanitize
    }, indent=2))

else:
    # Mode: analysis — output JSON of all sections with classification
    all_sections = extract_all_sections(content)
    sentinel_sections = extract_sentinel_sections(content)

    analysis = {
        'source': source_file,
        'total_sections': len(all_sections),
        'sentinel_sections': list(sentinel_sections.keys()),
        'sections': []
    }

    for sec in all_sections:
        classification = classify_section(sec['content'])
        analysis['sections'].append({
            'index': sec['index'],
            'header': sec['header'],
            'preview': sec['preview'],
            'classification': classification,
            'lines': len(sec['content'].split('\n'))
        })

    print(json.dumps(analysis, indent=2))
PYEOF
