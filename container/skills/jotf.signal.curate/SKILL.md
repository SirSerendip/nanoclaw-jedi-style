---
name: jotf.signal.curate
description: >
  Curate filtered signals into themed editorial sections with collision pairings,
  thinker-lens narratives, and pre-rendered HTML card fragments. The editorial
  engine of the Taster pipeline. Use when filtered signals are ready for section
  assembly and narrative writing.
  Triggers on: "curate signals", "build sections", "editorial assembly", "curate edition".
domain: signal
version: 0.1.0

context: fork
effort: high
allowed-tools: Read Write Glob

inputs:
  - name: filtered_signals_json
    type: file:json
    description: Filtered and scored signals from jotf.signal.filter
  - name: profile_json
    type: file:json
    description: Thinker persona profile from jotf.taster.persona

outputs:
  - name: curated_sections_json
    type: file:json
    description: Curated sections with HTML fragments at /workspace/group/taster/editions/{slug}/{date}/sections.json
    schema: schemas/curated-sections.schema.json

depends-on:
  - jotf.signal.filter
  - jotf.taster.persona
---

# Signal Curate — Editorial Section Assembly

Transform filtered signals into a curated edition with themed sections, collision pairings, thinker-lens narratives, and pre-rendered HTML card fragments.

## Quick Start

```
Curate the filtered signals for robyn-bolton from 2026-04-16
```

## Output Location

```
/workspace/group/taster/editions/{slug}/{date}/sections.json
```

## The Curation Process

### Step 1: Find Collisions

Scan all filtered signals for **unexpected pairings** — signals from different domains that illuminate each other:

- **Cross-domain tension** — An innovation signal that contradicts a strategy signal
- **Synergy discovery** — A biotech finding that validates a technology trend
- **Blind spot bridge** — A geopolitics signal that reshapes an innovation thesis

Each collision becomes a potential section anchor. Not every signal needs a collision partner — some are strong enough to stand alone.

### Step 2: Group into Sections

Organize signals into **4-6 themed sections**. Each section has:
- A **provocative title** (not just a category name — an editorial angle)
- A **section narrative** written in the persona's voice calibration
- **2-4 signal cards** with thinker-lens commentary
- A **section color** mapped from the persona's `design_palette` (section-1 through section-6)

**Section architecture guidelines:**
- Lead with the strongest collision or most provocative signal
- Each section should feel like a mini-essay with a throughline
- Vary section size — not every section needs the same number of cards
- The final section should feel like a "parting provocation" — leave the reader thinking

### Step 3: Select Thinkers

From the persona's `thinker_preferences` and the broader portfolio at `/workspace/group/references/thinker-portfolio.md`:

- Select **3-5 thinkers** for this edition
- **Rotate across editions** — don't use the same 3 every time. Check prior editions in the slug's directory if available.
- Each thinker frames 1-2 signal cards: "Through {Thinker}'s lens of {concept}, this signal reveals..."
- Thinker references should feel natural, not forced — only cite when it genuinely adds insight

### Step 4: Write Card Narratives

For each signal card, write:
1. **Headline** — punchy, specific, avoids jargon-for-jargon's-sake
2. **Narrative** — 2-4 sentences in the persona's voice that explain *why this signal matters to this specific reader*
3. **Thinker lens** (optional) — how a specific thinker's framework illuminates this signal
4. **Collision note** (if paired) — the unexpected connection to another signal
5. **Source link** — always include

### Step 5: Pre-Render HTML Fragments

For each signal card, generate an HTML fragment ready to be embedded in the final template. This keeps editorial intent coupled with presentation:

```html
<div class="signal">
  <p><strong>Goldman Sachs</strong> — <a href="https://..." target="_blank">Sir Sadiq Khan on London's Global Edge</a></p>
  <p>Through <em>Rita McGrath's</em> lens of transient advantage, London's pivot isn't about defending a position — it's about building optionality across AI, talent, and capital simultaneously. The Growth Plan reads less like urban policy and more like a corporate portfolio rebalance.</p>
  <p class="collision-note">↔ Collides with: The biotech regulatory signal below — both show institutions racing to set rules before the technology outpaces them.</p>
</div>
```

**Fragment rules:**
- Use semantic HTML only (no inline styles — the render skill applies CSS)
- Include `class="signal"` on the wrapper div
- Use `<strong>` for company/org names
- Use `<em>` for thinker names (will be styled as gold/accent in render)
- Use `<a>` with `target="_blank"` for source links
- Use `class="collision-note"` for collision annotations

## Output Schema

```json
{
  "metadata": {
    "persona": "robyn-bolton",
    "edition_date": "2026-04-16",
    "edition_title": "The First Mile Is Always Politics",
    "section_count": 5,
    "signal_count": 12,
    "thinkers_used": ["Clayton Christensen", "Rita McGrath", "Amy Edmondson"],
    "collision_pairs": 3
  },
  "sections": [
    {
      "title": "When Innovation Meets Its Own Antibodies",
      "narrative": "Section-level narrative introducing the theme...",
      "color_var": "--section-1",
      "cards": [
        {
          "company": "Source Org",
          "headline": "Card headline",
          "source_url": "https://...",
          "thinker_lens": "Clayton Christensen",
          "collision_partner": "card_id_of_paired_signal",
          "html_fragment": "<div class=\"signal\">...</div>",
          "signal_ref": { "...original signal data..." }
        }
      ]
    }
  ]
}
```

## Voice Calibration

Read the persona's `voice_calibration` carefully:
- **tone** — match it exactly. "Intellectually playful but substantive" means wit with depth, not fluff.
- **sentence_length** — if "varied," mix punchy 5-word insights with richer 20-word exposition.
- **la_force_voice** — this is how The Force (the editorial AI) adapts for this reader. It's a character, not a template.

## Error Handling

- **Too few signals** — If fewer than 6 filtered signals, create 2-3 sections instead of 4-6. Quality over structure.
- **No collisions found** — Not every edition will have natural collisions. Use standalone sections. Don't force connections that don't exist.
- **Missing thinker portfolio** — Fall back to the persona's `thinker_preferences` only.
- **Prior editions missing** — Can't check thinker rotation if no prior editions exist. Use the first run as the baseline.

## Changelog

- `0.1.0` — Initial release. Collision discovery, thinker rotation, pre-rendered HTML fragments.
