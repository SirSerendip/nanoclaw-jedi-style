---
name: jotf.taster.persona
description: >
  Create and manage thinker persona profiles for the Taster pipeline.
  Use when building a new taster profile, updating an existing profile,
  or when any pipeline skill needs to load a thinker's intellectual profile,
  design palette, filter lens, or delivery preferences.
  Triggers on: "create profile", "build persona", "taster profile", "thinker profile".
domain: taster
version: 0.1.0

allowed-tools: Read Write Edit Glob Grep

inputs:
  - name: thinker_name
    type: text
    description: Full name of the thinker to create or load a profile for
  - name: action
    type: text
    description: "One of: create, read, update, delete, list"
    required: false

outputs:
  - name: profile_json
    type: file:json
    description: Complete persona profile at /workspace/group/taster/profiles/{slug}.json
    schema: schemas/persona-profile.schema.json
---

# Taster Persona — Thinker Profile CRUD

Create, read, update, and delete thinker persona profiles that drive the entire Taster pipeline.

## Quick Start

```
Create a taster profile for Robyn Bolton
```

```
Load the persona profile for robyn-bolton
```

```
List all taster profiles
```

## Profile Location

All profiles are stored at:
```
/workspace/group/taster/profiles/{slug}.json
```

Where `{slug}` is the kebab-case version of the thinker's name (e.g., `robyn-bolton`).

## Commands

### create — Build a New Profile

When creating a new profile, conduct an **interview-style session**:

1. **Identify the thinker** — Ask for or confirm their name, professional background, and domains of expertise.
2. **Intellectual profile** — Determine their methodology, signature concepts, and what makes their thinking distinctive.
3. **MileZero metaphor** — Craft a personalized publication name and metaphor that captures their intellectual journey's starting point.
4. **Design palette** — Select colors, typography mood, and visual identity that reflects their intellectual brand. Map to CSS variables.
5. **Filter lens** — Define which signal domains resonate, their complexity comfort level, and critically: their **blind spots** (domains they'd normally ignore but should be exposed to).
6. **Voice calibration** — Set tone, sentence length preferences, thinker citation density, and how La Force's editorial voice adapts for this reader.
7. **Delivery config** — Email address, preferred format (inline HTML email, web link, Slack), cadence preferences.

**Reference the Thinker Portfolio** at `/workspace/group/references/thinker-portfolio.md` when selecting thinkers for the profile's `thinker_preferences`. This portfolio contains 250+ thinkers across 9 domains.

### read — Load an Existing Profile

```
Read the profile for robyn-bolton
```

Reads and returns the full JSON profile from `/workspace/group/taster/profiles/{slug}.json`.

### update — Modify a Profile

```
Update robyn-bolton's delivery cadence to M-W-F
```

Read the existing profile, apply changes, write back. Always preserve fields not being updated.

### delete — Remove a Profile

```
Delete the profile for test-user
```

Confirm with the user before deleting. Check if any scheduled tasks reference this profile first.

### list — Show All Profiles

```
List all taster profiles
```

Glob `/workspace/group/taster/profiles/*.json` and display a summary table.

## Profile Structure

```json
{
  "slug": "robyn-bolton",
  "name": "Robyn Bolton",
  "created": "2026-04-16",
  "updated": "2026-04-16",

  "intellectual_profile": {
    "background": "Innovation strategy consultant, former P&G innovator",
    "domains": ["innovation", "corporate-strategy", "design-thinking", "growth"],
    "methodology": "Jobs-to-be-Done, portfolio innovation, organizational ambidexterity",
    "signature_concepts": ["innovation portfolio", "corporate antibodies", "growth gap"],
    "distinction": "Bridges academic innovation theory with corporate execution reality"
  },

  "mile_zero": {
    "name": "MileZero",
    "metaphor": "The starting line of every innovation journey — where conviction meets uncertainty",
    "description": "A personalized intelligence brief for the innovation strategist who knows that the hardest mile is the first one.",
    "mood": "confident, forward-leaning, intellectually rigorous"
  },

  "design_palette": {
    "colors": {
      "--bg": "#0d1117",
      "--bg-card": "#161b22",
      "--bg-card-hover": "#1c2333",
      "--accent": "#58a6ff",
      "--gold": "#f0c040",
      "--text": "#e6edf3",
      "--text-muted": "#8b949e",
      "--section-1": "#58a6ff",
      "--section-2": "#3fb950",
      "--section-3": "#f0c040",
      "--section-4": "#bc8cff",
      "--section-5": "#ff7b72",
      "--section-6": "#79c0ff"
    },
    "typography": {
      "heading": "Playfair Display",
      "body": "Inter",
      "mono": "JetBrains Mono"
    },
    "mood": "clean, authoritative, modern"
  },

  "filter_lens": {
    "domains": ["innovation", "corporate-strategy", "technology", "market-disruption", "organizational-change"],
    "blind_spots": ["geopolitics", "biotech", "energy-transition", "creative-arts"],
    "complexity_level": "expert",
    "thinker_preferences": ["Clayton Christensen", "Rita McGrath", "Roger Martin", "Amy Edmondson", "Alex Osterwalder"]
  },

  "voice_calibration": {
    "tone": "intellectually playful but substantive — like a sharp colleague over espresso",
    "sentence_length": "varied — punchy insights mixed with deeper exposition",
    "thinker_usage": "weave 3-5 thinkers per edition, rotate across editions to avoid staleness",
    "la_force_voice": "confident curator who respects the reader's expertise and pushes their thinking"
  },

  "delivery": {
    "format": "email-inline",
    "email": "robyn@example.com",
    "cadence": "twice-weekly",
    "channels": ["email"],
    "subject_template": "MileZero · {edition_title} · {date}"
  }
}
```

## The Blind Spots Principle

The `filter_lens.blind_spots` array is the editorial differentiator. It lists domains the thinker would normally skip — but that's exactly where the most valuable collisions live.

During signal filtering, blind spot signals get a **bonus score**, ensuring 1-2 unexpected signals make it into every edition. This is what makes a Taster feel like it was written by someone who knows you *and* challenges you.

## Error Handling

- **Profile not found** — Check slug spelling. Run `list` to see available profiles.
- **Duplicate slug** — Warn the user. Offer to update existing or create with a suffix.
- **Missing thinker portfolio** — The portfolio at `/workspace/group/references/thinker-portfolio.md` is required for thinker selection. If missing, fall back to the thinkers listed in the user's request.

## Changelog

- `0.1.0` — Initial release. Interview-style creation, full CRUD, blind spots principle.
