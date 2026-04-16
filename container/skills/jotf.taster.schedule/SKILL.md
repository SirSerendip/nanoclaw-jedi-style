---
name: jotf.taster.schedule
description: >
  Schedule recurring Taster editions using smart cron presets. Creates NanoClaw
  scheduled tasks that wake a cold agent to run the full pipeline autonomously.
  Use when setting up recurring taster delivery, managing schedules, or adjusting
  delivery cadence. Triggers on: "schedule taster", "set cadence", "taster cron",
  "recurring taster", "delivery schedule".
domain: taster
version: 0.1.0

allowed-tools: Read Write Glob mcp__nanoclaw__schedule_task mcp__nanoclaw__list_tasks mcp__nanoclaw__pause_task mcp__nanoclaw__resume_task mcp__nanoclaw__cancel_task mcp__nanoclaw__update_task

inputs:
  - name: persona_slug
    type: text
    description: "Slug of the thinker persona to schedule (e.g., robyn-bolton)"
  - name: cadence
    type: text
    description: "Cadence preset or custom cron: daily, weekly, M-W-F, weekends, twice-weekly, or a raw cron expression"
    required: false
  - name: action
    type: text
    description: "One of: create, list, pause, resume, cancel, update"
    required: false

outputs:
  - name: schedule_config
    type: file:json
    description: Schedule config at /workspace/group/taster/schedules/{slug}.json

depends-on:
  - jotf.taster.persona
---

# Taster Schedule — Smart Cron Management

Set up recurring Taster editions that run autonomously — no human touch required.

## Quick Start

```
Schedule robyn-bolton taster twice-weekly at 2am ET
```

```
List all taster schedules
```

```
Pause the robyn-bolton schedule
```

## Cadence Presets

All times offset from :00 per NanoClaw scheduling guidance to avoid fleet-wide spike:

| Preset | Cron Expression | When |
|--------|----------------|------|
| `daily` | `3 7 * * *` | Every day at 7:03am ET |
| `weekly` | `7 7 * * 1` | Monday at 7:07am ET |
| `M-W-F` | `3 7 * * 1,3,5` | Mon, Wed, Fri at 7:03am ET |
| `weekends` | `7 9 * * 6,0` | Sat & Sun at 9:07am ET |
| `twice-weekly` | `0 2 * * 3,5` | Wed & Fri at 2:00am ET |
| Custom | Any valid cron | User-specified |

**Note on `twice-weekly`:** This is the Robyn Bolton default. Wednesday surfaces Mon-Tue signals (48h lookback), Friday surfaces Wed-Thu-Fri signals (72h lookback).

## Commands

### create — Set Up a New Schedule

1. **Read the persona profile** to get delivery config and cadence preference
2. **Determine cadence** — use the preset from the persona's `delivery.cadence`, or the user's explicit request
3. **Compute lookback logic** — build the prompt with day-aware lookback:
   - For `twice-weekly` (Wed+Fri): Wed=48h, Fri=72h
   - For `daily`: 24h
   - For `M-W-F`: Mon=72h (covers Fri-Sun), Wed=48h, Fri=48h
   - For `weekly`: 168h (full week)
   - For `weekends`: Sat=24h, Sun=48h
4. **Create the scheduled task** via `mcp__nanoclaw__schedule_task`
5. **Save the schedule config** to `/workspace/group/taster/schedules/{slug}.json`

#### The Scheduled Prompt

The prompt must be **self-contained** — a cold agent with no session context will execute it. Include:

```
Run the full Taster pipeline for {persona_name}:

1. PERSONA: Read the persona profile at /workspace/group/taster/profiles/{slug}.json

2. FETCH: Source signals from the last {lookback_hours} hours.
   - Use WebSearch to find 80-150 fresh signals across these domains: {domains_list}
   - Also check /workspace/group/taster/signals/ for any pre-staged local signal files
   - Write raw signals to /workspace/group/taster/signals/raw-{date}.json

3. FILTER: Apply the persona's filter lens to cut 99% of noise.
   - Score each signal against: domain match, blind spot illumination, complexity fit, thinker resonance, collision potential
   - Select top 8-14 signals, ensuring blind spot representation and domain diversity
   - Write to /workspace/group/taster/signals/filtered-{slug}-{date}.json

4. CURATE: Build 4-6 themed editorial sections with collision pairings.
   - Find cross-domain collisions between filtered signals
   - Select 3-5 thinkers from the portfolio at /workspace/group/references/thinker-portfolio.md
   - Write section narratives in the persona's voice
   - Pre-render HTML card fragments for each signal
   - Write to /workspace/group/taster/editions/{slug}/{date}/sections.json

5. RENDER: Generate dual HTML output.
   - web.html: CSS variables from persona palette, dark mode, responsive, Google Fonts
   - email.html: Inline CSS, table layout, no JS, max 600px, web-safe fonts
   - Write both to /workspace/group/taster/editions/{slug}/{date}/

6. DELIVER: Send via the persona's configured channels.
   - Email (inline): Build MIME message with email.html as body, send via curl SMTP
   - Subject line: {subject_template} with edition title and date
   - Recipient: {email}

Lookback logic: Today is {day_name}. Use {lookback_hours}h lookback.
If today is Wednesday, look back 48 hours (Monday-Tuesday signals).
If today is Friday, look back 72 hours (Wednesday-Thursday-Friday signals).
```

#### Task Configuration

```javascript
mcp__nanoclaw__schedule_task({
  prompt: "... the full prompt above ...",
  schedule_type: "cron",
  schedule_value: "{cron_expression}",
  context_mode: "isolated"  // Cold agent, no chat history needed
})
```

**Critical:** Use `context_mode: "isolated"` — the scheduled agent doesn't need chat history. All context is in the prompt itself.

### list — Show All Schedules

Glob `/workspace/group/taster/schedules/*.json` and display a summary table showing:
- Persona name
- Cadence preset
- Cron expression
- Task ID
- Status (active/paused)
- Last run / next run

Also cross-reference with `mcp__nanoclaw__list_tasks` to verify task status.

### pause — Temporarily Stop a Schedule

```
Pause the robyn-bolton taster schedule
```

1. Read the schedule config to get the task ID
2. Call `mcp__nanoclaw__pause_task` with the task ID
3. Update the schedule config status to "paused"

### resume — Restart a Paused Schedule

```
Resume the robyn-bolton schedule
```

1. Read the schedule config to get the task ID
2. Call `mcp__nanoclaw__resume_task` with the task ID
3. Update the schedule config status to "active"

### cancel — Remove a Schedule

```
Cancel the robyn-bolton taster schedule
```

1. Confirm with the user before canceling
2. Call `mcp__nanoclaw__cancel_task` with the task ID
3. Update the schedule config status to "cancelled"
4. Optionally delete the config file

### update — Change Schedule Parameters

```
Update robyn-bolton to M-W-F cadence
```

1. Read existing schedule config
2. Determine new cron expression
3. Call `mcp__nanoclaw__update_task` with new schedule
4. Update the config file

## Schedule Config File

Stored at `/workspace/group/taster/schedules/{slug}.json`:

```json
{
  "persona_slug": "robyn-bolton",
  "persona_name": "Robyn Bolton",
  "cadence_preset": "twice-weekly",
  "cron_expression": "0 2 * * 3,5",
  "task_id": "task-1713294000000-abc123",
  "status": "active",
  "lookback_rules": {
    "3": 48,
    "5": 72
  },
  "delivery_channels": ["email-inline"],
  "created_at": "2026-04-16T17:00:00-04:00",
  "updated_at": "2026-04-16T17:00:00-04:00",
  "last_run": null,
  "run_count": 0
}
```

The `lookback_rules` map day-of-week (0=Sun, 1=Mon, ...) to lookback hours. The scheduled prompt uses JavaScript's `new Date().getDay()` logic to pick the right value.

## Error Handling

- **Persona profile not found** — Cannot schedule without a profile. Direct user to create one with `jotf.taster.persona`.
- **Invalid cron expression** — Validate before submitting to NanoClaw. Use presets when possible.
- **Task creation failure** — Log the error. Most common: NanoClaw service unavailable. Retry once.
- **Orphaned tasks** — If a schedule config references a task ID that no longer exists in NanoClaw, warn the user and offer to recreate.
- **Duplicate schedules** — If a schedule already exists for this persona, warn and offer to update instead of creating a duplicate.

## Changelog

- `0.1.0` — Initial release. Smart cron presets, day-aware lookback, isolated context scheduling.
