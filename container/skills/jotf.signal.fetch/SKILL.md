---
name: jotf.signal.fetch
description: >
  Fetch and compile raw intelligence signals from web searches and local files.
  Use when sourcing fresh signals for a Taster edition, building a signal corpus,
  or refreshing the raw signal pool. Supports lookback windows for scheduled runs.
  Triggers on: "fetch signals", "source signals", "get signals", "signal scan".
domain: signal
version: 0.1.0

allowed-tools: Read Write WebSearch WebFetch Bash Glob

inputs:
  - name: lookback_hours
    type: text
    description: "How far back to search for signals (e.g., 24, 48, 72). Default: 48"
    required: false
  - name: domains
    type: text
    description: "Comma-separated focus domains for search queries (e.g., 'innovation,AI,strategy'). Optional — if omitted, uses broad business/tech signal scan."
    required: false
  - name: local_files
    type: text
    description: "Glob pattern for local signal files to ingest (e.g., '/workspace/group/*.json'). Optional."
    required: false

outputs:
  - name: raw_signals_json
    type: file:json
    description: Raw signals array at /workspace/group/taster/signals/raw-{date}.json
    schema: schemas/raw-signals.schema.json
---

# Signal Fetch — Raw Intelligence Sourcing

Compile raw intelligence signals from multiple sources into a standardized signal corpus.

## Quick Start

```
Fetch signals from the last 48 hours focused on innovation and corporate strategy
```

```
Fetch signals from local file /workspace/group/apr8-signals.json
```

## Output Location

```
/workspace/group/taster/signals/raw-{YYYY-MM-DD}.json
```

## Signal Format

Each signal follows the canonical format (from `apr8-signals.json`):

```json
{
  "date": "2026-04-16",
  "company": "Source Organization",
  "announcement": "Headline or title of the signal",
  "theme": "Primary Theme",
  "summary": "Multi-paragraph summary with bullet points.\n\n• Key point 1\n• Key point 2",
  "tags": ["tag-1", "tag-2", "tag-3"],
  "source_url": "https://example.com/article"
}
```

## Fetch Modes

### 1. WebSearch Mode (default for scheduled runs)

Run targeted web searches to find fresh signals. Build search queries from:
- Thinker's `filter_lens.domains` (if persona provided)
- General innovation/strategy/technology landscape
- Specific themes: AI, corporate transformation, market disruption, emerging tech, policy shifts

**Search strategy:**
1. Run 8-12 targeted WebSearch queries across different domains
2. For each promising result, use WebFetch to extract the full article
3. Synthesize each article into the canonical signal format
4. Target: **80-150 raw signals** per fetch (the filter stage will cut 99%)

**Lookback window:** Only include signals published within the `lookback_hours` window. For Wednesday runs this is 48h (Mon-Tue), for Friday runs this is 72h (Wed-Thu-Fri).

### 2. Local File Mode

Ingest existing signal files from disk:

```
Fetch signals from /workspace/group/apr8-signals.json
```

Read the file, validate each signal has required fields, normalize format, and write to output.

### 3. Hybrid Mode

Combine local files with fresh web searches:

```
Fetch signals: ingest /workspace/group/apr8-signals.json and supplement with 48h web search
```

## Workflow for Scheduled Runs

When invoked by the schedule skill (cold agent, no session context):

1. Compute lookback window from current day and `lookback_hours`
2. Run WebSearch queries across 8-12 domain verticals
3. Extract and format each signal
4. Deduplicate by source_url
5. Write to `/workspace/group/taster/signals/raw-{date}.json`
6. Report: signal count, domain distribution, date range covered

## Output Wrapper

```json
{
  "metadata": {
    "fetched_at": "2026-04-16T02:00:00-04:00",
    "lookback_hours": 48,
    "sources": {
      "web_search": 95,
      "local_file": 0
    },
    "total_signals": 95,
    "domain_distribution": {
      "innovation": 22,
      "technology": 18,
      "strategy": 15,
      "...": "..."
    }
  },
  "signals": [
    { "...signal objects..." }
  ]
}
```

## Error Handling

- **WebSearch rate limits** — Space queries 2-3 seconds apart. If rate limited, log and continue with signals already collected.
- **Empty results** — If fewer than 20 signals found, expand search domains and try broader queries. Warn if still under 20.
- **Malformed local file** — Validate each signal object. Skip malformed entries with a warning, don't fail the whole batch.
- **Duplicate signals** — Deduplicate by `source_url`. Keep the version with the richer summary.

## Changelog

- `0.1.0` — Initial release. WebSearch + local file ingestion, lookback windows.
