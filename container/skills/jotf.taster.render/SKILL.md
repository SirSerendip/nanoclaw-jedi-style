---
name: jotf.taster.render
description: >
  Build dual HTML output (web + email) from curated signal sections and a thinker
  persona profile. Produces a responsive dark-mode web page and an email-safe
  inline-CSS version. Use when curated sections are ready for final rendering.
  Triggers on: "render taster", "build html", "render edition", "generate taster html".
domain: taster
version: 0.1.0

context: fork
model: sonnet
allowed-tools: Read Write Glob Bash

inputs:
  - name: curated_sections_json
    type: file:json
    description: Curated sections with HTML card fragments from jotf.signal.curate
    schema: ../jotf.signal.curate/schemas/curated-sections.schema.json
  - name: profile_json
    type: file:json
    description: Thinker persona profile with design palette and mile_zero config

outputs:
  - name: web_html
    type: file:html
    description: Full web version at /workspace/group/taster/editions/{slug}/{date}/web.html
  - name: email_html
    type: file:html
    description: Email-safe version at /workspace/group/taster/editions/{slug}/{date}/email.html

depends-on:
  - jotf.signal.curate
  - jotf.taster.persona
---

# Taster Render — Dual HTML Builder

Generate both a web-optimized and email-safe HTML edition from curated signal sections.

## Quick Start

```
Render the taster edition for robyn-bolton from 2026-04-16
```

## Output Location

```
/workspace/group/taster/editions/{slug}/{date}/web.html
/workspace/group/taster/editions/{slug}/{date}/email.html
```

## Two Outputs, One Source

Both versions are built from the same `sections.json` — the signal card HTML fragments are already pre-rendered by the curate stage. The render skill wraps them in the appropriate template structure.

---

## Web Version (`web.html`)

### Template Pattern

Follow the pattern from `/workspace/group/references/smoke-break-template.html`:

1. **Google Fonts** — Load the fonts specified in the persona's `design_palette.typography` (heading, body, mono)
2. **CSS Variables** — Map the persona's `design_palette.colors` to CSS `:root` variables
3. **Dark mode** — Default dark theme. Optional light mode toggle via JS.
4. **Responsive** — Max-width 720px, mobile-friendly padding

### Page Structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{mile_zero.name} — {edition_title} — {date}</title>
  <!-- Google Fonts -->
  <!-- CSS: root vars from design_palette, full responsive styles -->
</head>
<body>
  <div class="container">
    <header>
      <h1>{mile_zero.name}</h1>
      <div class="date">{formatted_date}</div>
      <div class="subtitle">{mile_zero.description}</div>
      <div class="stats">
        <div class="stat"><div class="stat-value">{signal_count}</div><div class="stat-label">Signals</div></div>
        <div class="stat"><div class="stat-value">{section_count}</div><div class="stat-label">Sections</div></div>
        <div class="stat"><div class="stat-value">{thinker_count}</div><div class="stat-label">Thinkers</div></div>
      </div>
    </header>

    <!-- For each section -->
    <div class="section">
      <div class="section-header">
        <div class="section-dot" style="background: var({color_var})"></div>
        <h2>{section.title}</h2>
        <span class="section-count">{card_count} signals</span>
      </div>
      <p class="section-narrative">{section.narrative}</p>
      <!-- Pre-rendered card HTML fragments inserted here -->
      {cards[].html_fragment}
    </div>

    <footer>
      <div class="footer-french">{mile_zero.mood tagline}</div>
      <div class="footer-text">Curated by La Force · {date} · {mile_zero.name}</div>
    </footer>
  </div>
</body>
</html>
```

### CSS Requirements

- All section colors via CSS variables (`--section-1` through `--section-6`)
- Card hover effects (translateX, background shift)
- Section dots colored by section variable
- `<em>` tags (thinker names) styled with `--gold` color
- `.collision-note` styled with muted text, smaller font, left border
- Smooth radial gradient overlay (the "smoke" effect from the template)
- Stats bar centered with mono font values

---

## Email Version (`email.html`)

### Constraints

Email HTML is hostile territory. Follow these rules strictly:

1. **Table layout** — All structure via `<table>`, `<tr>`, `<td>`. No flexbox, grid, or float.
2. **Inline CSS** — Every styled element gets `style="..."` attributes. No `<style>` block (many clients strip it).
3. **No JavaScript** — Zero JS. No dark mode toggle. No animations.
4. **Max width 600px** — Centered table at 600px with white/light background fallback.
5. **Web-safe fonts** — Use Georgia for headings, Arial/Helvetica for body. Google Fonts won't load in email.
6. **Images as absolute URLs** — If any images are used, they must be absolute https:// URLs.
7. **Simplified palette** — Adapt the persona's dark palette for email readability. Light background with dark text is safer for email. Use accent colors for borders and highlights only.
8. **No CSS variables** — Hardcode all color values.

### Email Page Structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{mile_zero.name} — {edition_title}</title>
</head>
<body style="margin:0; padding:0; background-color:#f4f4f4; font-family:Arial, Helvetica, sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;">
    <tr>
      <td align="center" style="padding: 20px 10px;">
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff; border-radius:4px;">

          <!-- Masthead -->
          <tr>
            <td style="padding: 30px 40px 20px; text-align:center; border-bottom: 2px solid {accent};">
              <h1 style="font-family:Georgia,serif; font-size:28px; margin:0; color:#1a1a1a;">{mile_zero.name}</h1>
              <p style="font-family:Arial,sans-serif; font-size:12px; color:#666; letter-spacing:2px; text-transform:uppercase; margin:8px 0 0;">{formatted_date}</p>
              <p style="font-family:Georgia,serif; font-style:italic; font-size:14px; color:#888; margin:10px 0 0;">{edition_title}</p>
            </td>
          </tr>

          <!-- Stats bar -->
          <!-- Sections with cards (table-based layout) -->
          <!-- Footer -->

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

### Email Signal Card Template

```html
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:12px;">
  <tr>
    <td style="border-left: 3px solid {section_color}; padding: 12px 16px; background-color:#fafafa; border-radius:4px;">
      <p style="margin:0 0 6px; font-size:14px;"><strong style="color:#1a1a1a;">{company}</strong> — <a href="{source_url}" style="color:{accent}; text-decoration:none;">{headline}</a></p>
      <p style="margin:0; font-size:13px; line-height:1.6; color:#333;">{narrative_text}</p>
      <!-- Thinker lens in italic Georgia -->
      <!-- Collision note in smaller muted text -->
    </td>
  </tr>
</table>
```

### Email-Specific Handling

When rendering for email, you must **de-HTML** the pre-rendered card fragments from sections.json and rebuild them using table-based layout with inline styles. The web HTML fragments use CSS classes that won't work in email. Extract the semantic content (company, headline, narrative, thinker reference, collision note) from the fragments and re-render in email-safe format.

---

## Important: Complete HTML Document

Both `web.html` and `email.html` are **complete, self-contained HTML documents** — `<!DOCTYPE html>` through `</html>`. The deliver skill will send `email.html` as the full email body.

Note: `smtp-send` wraps the `--body` content in its own HTML structure. For inline email delivery, the deliver skill should construct the SMTP payload directly using curl to avoid double-wrapping. See `jotf.taster.deliver` for details.

## Error Handling

- **Missing design_palette** — Fall back to the Smoke Break template's default palette.
- **Missing card HTML fragments** — If `html_fragment` is empty for a card, generate it from the card's metadata (company, headline, source_url).
- **Too many sections** — If more than 6 sections, the 6th section color variable doesn't exist. Cycle back to section-1 colors.

## Changelog

- `0.1.0` — Initial release. Dual HTML output, CSS variable theming, email-safe table layout.
