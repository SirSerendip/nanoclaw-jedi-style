---
name: jotf.intel.library
description: Search and contribute to the JOTF shared knowledge library — curated institutional memory across all JOTF business channels.
domain: intel
version: 0.1.0
inputs:
  - name: query
    type: text
    description: Search query or content to ingest
outputs:
  - name: results
    type: json
    description: Matching library entries with scores
---

# JOTF Shared Library

A curated vectorstore of JOTF institutional knowledge: lessons learned, strategic decisions, contacts, meeting transcripts, MeetOS analyses, founder backstories, and more. Searchable by meaning, filterable by category, origin channel, author, date, and tags.

## Scope: JOTF Channels Only

This library is for JOTF business channels. Before using:
- **Allowed**: `slack_main`, `slack_meetos`, `slack_random`, and future JOTF channels
- **Not allowed**: `slack_just-me-and-the-force` (Unlikely Bits), `slack_curtismichelson-com`, `whatsapp_main`, or other non-JOTF groups

If you're in a non-JOTF channel, politely decline: "The shared library is scoped to JOTF business channels."

## How to Search

Search runs directly against the read-only global mount — no IPC needed.

**Path depends on your group:**
- Non-main groups: `cd /workspace/global/library && node search.mjs "your query"`
- Main group: `cd /workspace/project/groups/global/library && node search.mjs "your query"`

**Options:**
- `--top 10` — more results (default: 5)
- `--category lesson` — filter by type: `lesson`, `decision`, `contact`, `transcript`, `analysis`, `backstory`, `journal`, `archive`, `misc`
- `--category decision,lesson` — multiple categories (comma-separated)
- `--origin slack_meetos` — filter by source channel
- `--author "Curtis"` — filter by author/speaker (partial match)
- `--date "2026-04"` — filter by content date (YYYY-MM or YYYY-MM-DD prefix)
- `--tags "moat"` — filter by tag (partial match)
- `--section "decisions"` — filter by section heading (partial match)
- `--verbose` — structured JSON output

**Examples:**
```bash
node search.mjs "moat strategy and competitive advantage"
node search.mjs --category decision "pricing model"
node search.mjs --category lesson "SVG rendering"
node search.mjs --origin slack_meetos --category transcript "Q2 roadmap"
node search.mjs --author "Hamid" "product direction"
node search.mjs --date "2026-04" "brand guidelines"
```

### When to Search

- When the user asks "have we discussed X before?" or "what's our position on Y?"
- Before making decisions that might have prior art in the library
- When referencing past meeting outcomes or action items
- When preparing briefs, artifacts, or proposals that need grounding in prior work
- When looking for patterns across channels ("how many times have we covered this topic?")

### First-Time Setup

If `node_modules/` doesn't exist in the library directory:
```bash
cd /workspace/global/library && npm install
```
(or `/workspace/project/groups/global/library` for main group)

## How to Ingest (Put Something in the Library)

Ingestion is **curated** — only add content when the user explicitly asks. Trigger phrases:
- "put this in the library"
- "library this"
- "save to library"
- "add to library"

### Ingestion via IPC

Write a JSON request file to your IPC library directory, then poll for the result.

**Step 1: Write the request**
```bash
cat > /workspace/ipc/library/ingest-$(date +%s).json << 'ENDJSON'
{
  "type": "library_ingest",
  "requestId": "lib-TIMESTAMP-RANDOM",
  "content": "The full text content to ingest (markdown preferred)",
  "filename": "descriptive-name.md",
  "category": "lesson",
  "tags": "relevant,tags,here",
  "author": "Curtis",
  "contentDate": "2026-04-09",
  "originChannel": "slack_main"
}
ENDJSON
```

**Step 2: Poll for result**
```bash
# Check every 2 seconds for up to 60 seconds
for i in $(seq 1 30); do
  RESULT=$(ls /workspace/ipc/library/result-lib-*.json 2>/dev/null | head -1)
  if [ -n "$RESULT" ]; then
    cat "$RESULT"
    rm "$RESULT"
    break
  fi
  sleep 2
done
```

### Request Fields

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Must be `"library_ingest"` |
| `requestId` | Yes | Unique ID for this request (use `lib-{timestamp}-{random}`) |
| `content` | Yes | The full text to ingest (markdown preferred) |
| `filename` | Yes | Suggested filename (will be saved as `sources/{category}/{filename}`) |
| `category` | Yes | One of: `lesson`, `decision`, `contact`, `transcript`, `analysis`, `backstory`, `journal`, `archive`, `misc` |
| `tags` | No | Comma-separated tags for filtering |
| `author` | No | Who wrote/said this content |
| `contentDate` | No | When the content is from (YYYY-MM-DD) |
| `originChannel` | No | Which channel this came from (auto-detected if omitted) |

### What to Ingest

Good library material:
- Lessons learned (with Why context — why it matters)
- Strategic decisions (with rationale and constraints)
- Meeting transcripts and MeetOS analyses (especially those with key decisions)
- Contact profiles and relationship context
- Foundational backstory or business context documents
- Ideas or insights the user explicitly wants preserved

**Not** library material:
- Routine config or formatting rules (channel-specific)
- Ephemeral status updates
- Conversation chatter

### After MeetOS Analysis

When this skill is used alongside MeetOS in the meetos channel: after completing a MeetOS analysis, ask the user: "Want me to add the key decisions and outcomes to the shared library?"

If yes, extract the decisions and action items sections and ingest them with:
- `category`: `analysis`
- `tags`: derived from meeting type and key topics
- `author`: meeting participants
- `contentDate`: meeting date

## Categories Reference

| Category | What belongs | Chunking |
|----------|-------------|----------|
| `lesson` | Operational lessons with Why blocks | By H3 heading |
| `decision` | Strategic decisions with Rationale | By H3 heading |
| `contact` | Person profiles, relationship context | By H3 heading (per person) |
| `transcript` | Meeting transcripts | By speaker turns (~500 words) |
| `analysis` | MeetOS analyses | By semantic section |
| `backstory` | Founder/company origin stories | By person > chapter |
| `journal` | Session journals, work logs | By dated entry |
| `archive` | Historical documents, audits, digs | Simple 500-word chunks |
| `misc` | Anything else worth preserving | Simple 500-word chunks |
