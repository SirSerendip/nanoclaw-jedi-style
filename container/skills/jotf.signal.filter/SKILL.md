---
name: jotf.signal.filter
description: >
  Apply persona-lens noise reduction to raw signals, cutting 99% of noise to surface
  only the most relevant and provocative signals for a thinker. Scores each signal
  against the persona's filter lens including blind spot bonus scoring.
  Use when raw signals are ready for persona-specific filtering.
  Triggers on: "filter signals", "apply filter", "reduce signals", "signal filter".
domain: signal
version: 0.1.0

context: fork
effort: high
allowed-tools: Read Write

inputs:
  - name: raw_signals_json
    type: file:json
    description: Raw signals corpus from jotf.signal.fetch
  - name: profile_json
    type: file:json
    description: Thinker persona profile from jotf.taster.persona

outputs:
  - name: filtered_signals_json
    type: file:json
    description: Filtered signals with scores at /workspace/group/taster/signals/filtered-{slug}-{date}.json

depends-on:
  - jotf.signal.fetch
  - jotf.taster.persona
---

# Signal Filter — Persona-Lens Noise Reduction

Apply deep persona-aware filtering to reduce 80-150 raw signals down to 8-14 survivors.

## Quick Start

```
Filter signals in /workspace/group/taster/signals/raw-2026-04-16.json
through the robyn-bolton persona
```

## The 99% Cut

This is the editorial heart of the Taster pipeline. Like Anna's edition that cut 1,199 signals down to 12 — every signal must earn its place.

## Scoring Dimensions

For each raw signal, compute a composite score (0-100) across five dimensions:

### 1. Domain Match (0-25 pts)
How well does the signal align with the persona's `filter_lens.domains`?
- Direct domain hit: 20-25 pts
- Adjacent domain (1 hop away): 10-15 pts
- Unrelated domain: 0-5 pts

### 2. Blind Spot Illumination (0-25 pts — BONUS)
Does the signal fall within the persona's `filter_lens.blind_spots`?
- Direct blind spot hit with clear relevance to core domains: 20-25 pts
- Tangential blind spot connection: 10-15 pts
- Not a blind spot: 0 pts

**This is the editorial differentiator.** Blind spot signals that connect back to the thinker's core interests create the most valuable collisions. A geopolitics signal that illuminates an innovation strategy insight is gold.

### 3. Complexity Fit (0-15 pts)
Does the signal match the persona's `complexity_level`?
- Expert-level thinker getting expert-level content: 15 pts
- Slight mismatch (too simple or too niche): 5-10 pts
- Major mismatch: 0-5 pts

### 4. Thinker Resonance (0-20 pts)
Could this signal be illuminated through the lens of one of the persona's preferred thinkers?
- Strong fit with a specific thinker's framework: 15-20 pts
- Moderate fit: 8-12 pts
- No clear thinker connection: 0-5 pts

### 5. Collision Potential (0-15 pts)
Could this signal create a surprising collision when paired with another signal?
- High cross-domain tension or synergy: 12-15 pts
- Moderate pairing potential: 5-10 pts
- Standalone only: 0-5 pts

## Selection Rules

1. **Score all signals** across all five dimensions
2. **Rank by composite score** (sum of all dimensions, max 100)
3. **Select top 8-14 signals** — hard floor of 8, hard ceiling of 14
4. **Ensure blind spot representation** — at least 1-2 signals from blind spot domains must survive. If none scored high enough organically, promote the highest-scoring blind spot signal into the set.
5. **Ensure domain diversity** — no more than 4 signals from the same domain. Demote duplicative domain signals in favor of underrepresented domains.

## Output Format

```json
{
  "metadata": {
    "persona": "robyn-bolton",
    "filtered_at": "2026-04-16T02:01:00-04:00",
    "input_count": 95,
    "output_count": 12,
    "reduction_pct": 87.4,
    "blind_spot_signals": 2,
    "domain_spread": ["innovation", "technology", "geopolitics", "biotech", "strategy"]
  },
  "signals": [
    {
      "date": "2026-04-16",
      "company": "Source Org",
      "announcement": "Headline",
      "theme": "Theme",
      "summary": "Summary text...",
      "tags": ["tag-1", "tag-2"],
      "source_url": "https://...",

      "filter_score": 78,
      "filter_breakdown": {
        "domain_match": 22,
        "blind_spot_illumination": 18,
        "complexity_fit": 13,
        "thinker_resonance": 15,
        "collision_potential": 10
      },
      "filter_reasons": [
        "Direct hit on innovation strategy — Robyn's core domain",
        "Connects to Clayton Christensen's disruption framework",
        "High collision potential with biotech regulatory signal"
      ],
      "suggested_thinker_lens": "Clayton Christensen",
      "is_blind_spot": true
    }
  ]
}
```

## Workflow

1. **Read** the raw signals file and persona profile
2. **Score** every signal across all 5 dimensions — do not skip any
3. **Rank** by composite score
4. **Apply selection rules** (blind spot guarantee, domain diversity cap)
5. **Write** filtered output to `/workspace/group/taster/signals/filtered-{slug}-{date}.json`
6. **Report** summary: input count, output count, reduction %, blind spot count, domain spread

## Error Handling

- **Too few signals** — If input has fewer than 15 signals, lower the threshold but still apply scoring. Minimum output: 5 signals.
- **No blind spot signals** — If zero blind spot signals exist in the input, note this in metadata but don't fail. The fetch stage may not have covered those domains.
- **Missing persona fields** — If `filter_lens` is incomplete, fall back to domain matching only. Warn about missing blind spots.

## Changelog

- `0.1.0` — Initial release. Five-dimension scoring, blind spot bonus, domain diversity enforcement.
