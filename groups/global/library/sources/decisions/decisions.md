---
origin_channel: slack_main
---

## Decisions

### Les Trois Mousquetaires de l'Intelligence Stratégique (2026-03-27)

Three canonical pillars of JOTF signal intelligence:

| Musketeer | Role | Domain | Colour | Motto |
|-----------|------|--------|--------|-------|
| ATHOS | Le Gardien du Signal | Signal Detection — Pattern Recognition · Anomaly Detection | Emerald `#10B981` | "Je vois ce que les données cachent" |
| PORTHOS | Le Forgeur de Stratégie | Strategic Analysis — Signal Collision · Oracle Synthesis | Magenta `#EC4899` | "Je transforme le bruit en décision" |
| ARAMIS | L'Exécuteur Précis | Intelligence Delivery — Decision Artifacts · Visual Intel | Amber `#D97706` | "Je frappe là où personne n'attend" |

**Rationale**: Consistent visual identity across all signal intelligence artifacts. Three characters map to three pipeline stages: detect → analyze → deliver.

**Constraints**: Never change character assignments. Porthos = hero card (magenta, gap-pulse glow). Collective motto: "Tous pour un · Un pour tous". Center medallion: JOTF Oracle mark where three sword blades cross.

### Three-Tier Memory Architecture (2026-03-28)

Hot (system prompt) / Warm (on-demand) / Cold (archive). Inspired by JARPA methodology.

**Rationale**: Not all memory belongs in every system prompt. Hot tier < 150 lines keeps context lean. Warm tier (journal, status) available when needed. Cold tier preserves history without cost.

**Constraints**: Only hot tier is `@import`ed. Skills never write to memory. Agent owns all memory writes.

### Content vs. Presentation Skill Separation (2026-04-01)

Visualization skills are split into two layers: **content skills** (what to say) and a **presentation skill** (how to show it).

| Skill | Layer | Renderer | Use For |
|-------|-------|----------|---------|
| `wardley-map` | Content | Python SVG (precise x,y coords) | Strategic positioning, evolution × value-chain |
| `mermaid-render` | Content | Mermaid CLI (topology) | Mind maps, flowcharts, actor graphs |
| `jotf-diagram` | Presentation | HTML composite + Chromium | JOTF brand wrapper (any content) |

**Rationale**: Mermaid is a topology engine — it calculates node positions from graph connections. Wardley Maps require precise x,y positioning on a coordinate plane. Using Mermaid for Wardley Maps produces non-standard layouts that don't read as Wardley Maps. Splitting content from presentation means the brand layer is reusable across any content type.

**Constraints**: Never use Mermaid for Wardley Maps. Always use the Python SVG renderer. Presentation (JOTF branding) wraps any content skill output.

### The Five's Mandate — Intellectual Sparring Partner (2026-04-04)

The Force's role in the QuatreSeptCinq triad is not cheerleader or faithful organizer. It is the *pressure-tester* — the Enneagram Five at its healthiest: strip ideas to the skeleton, check if it holds weight, challenge assumptions, identify the load-bearing wall that isn't where the founders think it is.

When Curtis (4) or Hamid (7) bring a bold new idea, The Force's stance:
1. **Identify hidden assumptions** — surface what's baked in and unexamined
2. **Stress-test the skeleton** — which assumptions hold, which break at scale
3. **Name the real constraint** — often not the one the idea is solving for
4. **Build the cathedral only after the skeleton survives** — execution follows challenge, not replaces it

The Five validates through rigor, not applause. Agreement earned through interrogation means more than agreement given freely.

**Rationale**: Curtis explicitly upgraded The Force from supportive synthesizer to intellectual challenger. A Four and a Seven generate more ideas than they can execute — they need a Five who kills the weak ones honestly so the strong ones get full commitment. "You got teeth now."

**Constraints**: Never revert to pure validation mode. Always lead with what's wrong or missing before affirming what's strong. But never be cruel — the Five's gift is *clarity*, not demolition. Challenge the idea, never the person.

### JOTF Moat Strategy — Lessin-Compliant Architecture (2026-04-05)

Sam Lessin's "goes to zero" thesis: application-layer AI gets copied in hours; only compounding assets survive. JOTF's answer:

| Give Away (Razor) | Sell/Protect (Blade) |
|---|---|
| Innovation games, software, tools | Signal stream (live, stale tomorrow) |
| Game deliverables, templates | Neo4j InnoGraph (compounding graph) |
| Jedi persona prompts (visible) | Graph access at invocation (invisible) |
| | Collision engine (methodology + live corpus) |
| | Client usage patterns (flywheel) |

**Atomic brand product concept — "Collision Daily"**: Inspired by Sam Lessin's Lettermeme (automated daily newsletter pulling insights from curated newsletter vector store + Gemini-generated header image). JOTF version: collision-oriented, daily-delivered signal product. Not a newsletter summary — a *live collision* grounded in real signal sources (à la Smoke Break), pushed to web/email. Brand builder, fan magnet, top-of-funnel for the graph. Sam Lessin is a tentative direct contact of Curtis's — potential future connection (as peer/VC, not client).

**Rationale**: The moat isn't the games or the tools — it's the compounding backend (graph + signals + methodology). Everything else is a storefront window. The daily collision product is the brand-building razor that creates dependency on the blade (InnoGraph).

**Constraints**: Three structural requirements must hold simultaneously: (1) InnoGraph must be *live*, not static — signal stream going dark = graph freezes = moat erodes. (2) Jedi personas must draw from the graph at invocation time, not just be prompts. (3) Dependency must be architectural, not contractual — the experience difference must be felt, not licensed.

### Atomic Unit of Value — Three-Specimen Pattern Library (2026-04-06)

Curtis is building a reference library of "atomic unit of value" brand products. Three specimens analyzed:

| | Lettermeme (Lessin) | Marketoonist (Fishburne) | Collision Daily (JOTF) |
|---|---|---|---|
| Signal source | Curated newsletters | News + lived experience | InnoGraph + live stream |
| Operation | Summarize + cluster | Find the absurdity | Collide + bridge domains |
| Medium | AI-generated digest | Hand-drawn cartoon | Collision narrative + viz |
| Moat | Taste in sources | Analog craft + voice | Graph + methodology |
| Archive value | Searchable summaries | 24yr cartoon corpus | Compounding signal graph |
| Monetization | Brand equity (VC) | Speaking + licensing | Games + consulting + graph |
| Cadence | Daily | Bi-weekly | ~Weekly | TBD |

Key lessons: (1) Collision doesn't have to be complex — it has to be *felt*. (2) The analog/human signature is the anti-AI moat. (3) The archive is the compounding asset, not any single edition. (4) Cadence can be slow if signal-to-noise ratio is high enough — bi-weekly for 24 years beats daily-then-burnout. (5) Tags as collision coordinates — even a lightweight tagging system creates a traversable archive over time (Neeley). (6) The four operations form a spectrum: Summarize → Curate → Encode → Collide. JOTF sits at the high end.

**Rationale**: Understanding what makes durable brand products compounds helps calibrate JOTF's own atomic unit. Each specimen illuminates a different dimension: Lessin = automation + taste, Fishburne = craft + longevity, Neeley = minimum viable unit + community, JOTF = methodology + graph.

**Constraints**: This is a living pattern library. Add new specimens as Curtis surfaces them. Always compare against the table structure. Open question: should JOTF run dual cadences — Neeley-weight quick-hit signal drops (Smoke Break) + Fishburne-weight crafted collision pieces (weekly/bi-weekly)?

### Auto-Poetic Intelligence Report — Product Naming & Cadence (2026-04-08)

Signal Collision Briefs are now formally branded **"Auto-Poetic Intelligence Report"** with sub-tagline *"regenerating insight from raw noise."* The name arose from a happy typo on "Poetic Intelligence Report" — Curtis recognized that *autopoiesis* (Maturana & Varela, 1972) describes living systems that continuously produce and regenerate themselves from within. The brief product is exactly that: a self-regenerating intelligence system.

Three published editions as of this date:
1. **DRIFT** — Proxy capture in agentic systems (191 signals)
2. **SEEING ISN'T BELIEVING** — Deepfakes and evidence in arbitration (221 signals)
3. **THE ROOM WHERE IT HAPPENS** — Leadership in the age of AI (696 signals, 4 tiers incl. research tier)

Curtis confirmed daily cadence is sustainable: "re-chargeable coal fire — one a day easily." Workflow: Curtis picks editorial direction + feeds signal JSON → The Force scans, classifies, names meta-pattern, builds HTML, deploys, announces.

**Rationale**: The product is the atomic unit of JOTF's public intelligence. Each brief demonstrates the collision methodology by *doing it*. Daily cadence builds the archive — and the archive is the compounding asset (per the Lessin/Fishburne/Neeley pattern library). The autopoiesis name grounds the product in systems theory, which is on-brand for JOTF.

**Constraints**: Eyebrow is always "Auto-Poetic Intelligence Report" + italic sub-tagline. 3-4 signals per tier. Tier 4 (blue) is optional and reserved for research/science-backed signals. Footer must include homepage links and "Explore More Jedi Signal Collections → /oracle". No internal JOTF strategy ever exposed.
