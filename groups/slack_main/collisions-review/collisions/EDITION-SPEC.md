# Signal Collisions Edition — JSON Data Spec

This document defines the JSON format for producing new Signal Collision editions.
Each edition is a JSON file placed in `collisions/editions/` and rendered by `collisions/template.php`.

## How to publish a new edition

1. Create the JSON file: `collisions/editions/YYYY-MM-DD.json`
2. Create a thin PHP loader: `collisions/{slug}.php` containing:
   ```php
   <?php
   $edition = json_decode(file_get_contents(__DIR__ . '/editions/YYYY-MM-DD.json'), true);
   include __DIR__ . '/template.php';
   ```
3. Update `data/sections/oracle-editions.html` with the new edition's card details and link

## JSON Schema

```json
{
  "slug": "string — URL-safe identifier, used in filename and OG URL (e.g. enterprise-ai-april-2026)",
  "dateRange": "string — human-readable date range shown in hero (e.g. April 1-14, 2026)",
  "publishDate": "string — ISO date of publication (e.g. 2026-04-14)",
  "metaTitle": "string — full <title> tag content",
  "metaDescription": "string — meta description for SEO",
  "ogTitle": "string — Open Graph title",
  "ogDescription": "string — Open Graph description",
  "manifesto": "string — 1-2 sentence intro paragraph below the stats bar",
  "stats": [
    {
      "number": "string — the big stat (e.g. 40+, 7, 12)",
      "label": "string — what it measures (e.g. Signals Tracked, Collisions Detected)"
    }
  ],
  "collisions": [
    {
      "number": "string — zero-padded display number (01, 02, etc.)",
      "title": "string — collision headline (e.g. The Invisible C-Suite)",
      "subtitle": "string — italic subhead (e.g. When AI fills the corner office before anyone notices)",
      "narrative": "string (HTML) — the main editorial paragraph. Use <strong> for company names, <em> for emphasis. Avoid em-dashes and 'not X, it's Y' constructs in the closing line.",
      "now": "string (HTML) — The Now block content. Lead with a <strong> bold thesis sentence.",
      "next": "string (HTML) — What's Next block content. Lead with a <strong> bold thesis sentence. Use <em> for closing emphasis if needed.",
      "signals": [
        {
          "source": "string — publication name (e.g. VentureBeat, NVIDIA Blog)",
          "title": "string — headline of the source article",
          "url": "string — full URL to the source article",
          "summary": "string — 1-2 sentence plain-text summary of the article"
        }
      ]
    }
  ],
  "frontier": {
    "description": "string — intro paragraph for the Frontier Science section",
    "cards": [
      {
        "category": "string — research category label (e.g. Compute Efficiency, AI Safety)",
        "title": "string — headline of the research item",
        "url": "string — full URL to the source",
        "summary": "string — 1-2 sentence plain-text summary"
      }
    ]
  }
}
```

## Field details

### Edition metadata
- `slug`: Used to construct the PHP filename and OG URL. Convention: `{topic}-{month}-{year}` (e.g. `enterprise-ai-april-2026`)
- `dateRange`: Displayed in the hero badge. Format: `Month DD-DD, YYYY` (e.g. `April 1-14, 2026`)
- `publishDate`: ISO format. Used for sorting/archiving
- `stats`: Typically 4-5 items. Common set: Signals Tracked, Collisions Detected, Industries, Publications, Signal Window

### Collisions (typically 5-8 per edition)
- `number`: Zero-padded string matching array position (`"01"`, `"02"`, etc.)
- `narrative`: Rich HTML. Use `<strong>Company Name</strong>` for every company mentioned. End with a plain, non-formulaic closing observation — avoid "This isn't X. It's Y." and em-dash punchlines
- `now`: The factual present tense. What is already happening. Rich HTML
- `next`: Speculative near-future. What this implies over 12-36 months. Rich HTML
- `signals`: 3-6 source articles per collision. Each must have a real, verifiable URL
- The template auto-assigns color classes (`collision-1` through `collision-7`) based on array index. Colors cycle if more than 7 collisions

### Frontier Science (typically 6-10 cards)
- Research-oriented items that underpin the enterprise stories above
- Each card has a category tag, linked title, and summary
- The template cycles `reveal-delay-1/2/3` for staggered animation

## Template constants (not in JSON)
These are baked into `template.php` and stay the same every edition:
- Hero title: "The Now & the Next"
- Hero subtitle: "Frontier science meets business strategy. A bi-weekly speculative fiction suggesting the shape of things to come."
- Animated SVG constellation bug
- Now/Next block labels: "⚡ The Now" / "→ What's Next"
- "Supporting Headlines" label on signal lists
- "Signal Collision" eyebrow on each collision
- "From the Lab Bench" label on frontier section
- Frontier section title: "Frontier Science Feeding the Machine"
- All CSS, animations, responsive styles
- Scroll-down hint arrow
- Site navigation (PHP include)

## Writing guidelines for narrative fields
1. Use `<strong>` around every company name on first mention
2. Use `<em>` sparingly for genuine emphasis, not for style
3. Close each narrative with a plain observation — no rhetorical inversions
4. The `now` field should be grounded in facts from the signals
5. The `next` field is speculative — where this goes in 12-36 months
6. Signal summaries should be factual and concise — 1-2 sentences max
7. All URLs must be real, verifiable links to published articles
