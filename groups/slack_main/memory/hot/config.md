## Configuration

| Key | Value | Notes |
|-----|-------|-------|
| Slack bold | `*text*` single asterisk | `**` renders as literal characters |
| Slack URLs | Never bold | Breaks link rendering |
| Slack italics | `_text_` | Standard mrkdwn |
| Slack code | Backticks `` `code` `` | Triple for blocks |
| SVG ampersand | Escape as `&amp;` | Bare `&` → `xmlParseEntityRef` error |
| SVG validation | `xml.etree.ElementTree.parse()` | Run before every upload |
| Mermaid embed: style | Extract `<style>` → place at outer SVG root | Mermaid scopes CSS to `#my-svg` |
| Mermaid embed: wrapper | Wrap inner content in `<g id="my-svg">` | Without this, all nodes render black |
| Mermaid embed: transform | `<g transform>` wraps the `<g id="my-svg">` | Scale/translate on outer group |
| File upload primary | catbox.moe `reqtype=fileupload` | Permanent hosting |
| File upload fallback | litterbox.catbox.moe | 72h temporary |
| SVG constants module | `/workspace/ipc/files/jotf_svg_constants.py` | `import sys; sys.path.insert(0, '/workspace/ipc/files')` |
| SID meaning | Super Insight Digger | Hamid's coinage |
| Slack channel SID | `#C089UP13YDN` | Deep insight mining channel |
| Slack channel tested | `#C040UETETD5` | First Slack MCP test channel |
| JOTF site content path | `/workspace/extra/jedionthefly.com/data/sections/*.html` | Raw content files for GEO audit |
| Collisions editions path | `/workspace/extra/jedionthefly.com/collisions/editions/*.json` | Collision JSON files |
| GEO rubric source | `/home/node/.claude/skills/mind-trick/` | Citability scoring, AI crawler guidance |
| French→English rule | When Hamid speaks French, always start response with English translation (or educated summary if sufficient) | So Curtis always knows what was said |
| Signal collision briefs | Public-facing only — NO "What it means for JOTF" sections | Internal insights stay internal; briefs are for external distribution |
| Signal brief skill | `signal-collision-brief` | Input: Jedi Signals JSON (file or backend). Output: branded HTML artifact with source links |
| Brief product name | Auto-Poetic Intelligence Report | Eyebrow on all briefs. Nod to autopoiesis (Maturana & Varela) |
| Brief sub-eyebrow | "regenerating insight from raw noise" | Tiny italic, slate-500, below eyebrow |
| Brief tier colors | T1=Red, T2=Orange, T3=Yellow, T4=Blue (#3B82F6) | T4 = research/science tier (optional) |
| Brief tier size | 3-4 signals per tier | Curtis prefers tight tiers over sprawl |
| Brief footer links | Logo→homepage, branding→homepage, "Explore More"→/oracle, ©→homepage | Portal pattern for public visitors |
| Brief FTP path | Upload to `/briefs/` → live at `/collisions/briefs/` | FTP root maps differently than web URL |
| Brief cadence | Daily-capable | "Re-chargeable coal fire. One a day easily." |
| Collisions FTP root | FTP root = `/collisions/` folder | Upload editions to `/editions/`, PHP loaders to `/`, NOT `/collisions/editions/` |
| Collisions cadence | Bi-weekly for Scott Kirsner / InnoLead | Two feeds: enterprise signals JSON + research signals JSON |
| Collisions edition spec | `collisions/EDITION-SPEC.md` | JSON schema, writing rules, publishing steps |
| Collisions components | 1) Edition JSON, 2) PHP loader, 3) oracle-editions.html update, 4) Newsletter abstract for Scott | All four deliverables every edition |
| InnoLead abstract style | 6 bullets, household consumer brands preferred over geeky/infra | Company bold, 1-2 sentence summary, "Read more »" linked, closer links to live page |
| InnoLead audience | Scott Kirsner, Innovation Leader magazine | Approachable, exec-friendly, well-known brands. Less chipmaker, more Ford/UPS/Ulta |
| InnoLead recipient | Scott Kirsner | He plugs us in his newsletter with "from our friends at Jedi on the Fly" |
| ManBite task ID | task-1776388099995-cdj2ic | Daily 1am ET (cron `0 5 * * *`), full Taster pipeline, email to me@curtismichelson.com |
| ManBite old task | task-1776209171237-a3pofj | CANCELLED — replaced by Taster pipeline 2026-04-16 |
| ManBite template | `references/manbite-template.html` | Light-mode default, dark toggle, 18px base font |
| ManBite delivery | Email inline (curl SMTP) | Migrated from Slack DM to email 2026-04-16 |
| ManBite persona | `taster/profiles/curtis-michelson.json` | Full Taster persona with inversion-strength scoring |
| ManBite filter | Counter-intuitive inversions only | 4 tiers: Inversions, Narrative Collisions, Paradigm Cracks, Metaphor Mining. Prioritize multi-signal collisions (2 signals juxtaposed). |
| ManBite voice | Direct, provocative, no French | Drumming metaphors OK. "What would make Curtis say wait WHAT?" |
| Curtis's book | "The Unlikely Bits: How The Best Designers, Disruptors and Detectives Leverage Clues Others Miss" | Interviewing innovation leaders inc. Anna Caraveli |
| TGV Express task ID | task-1776394581388-bxgtc4 | Wed+Fri 3am ET (cron `0 7 * * 3,5`), full Taster pipeline, email to caraveli.anna3@gmail.com |
| TGV Express persona | `taster/profiles/anna-caraveli.json` | Reframe-depth scoring, Mediterranean palette, 4 sections |
| TGV Express template | `references/tgv-express-template.html` | Aegean/terracotta/olive/lavender, Playfair Display + Source Serif 4 |
| TGV Express filter | Reframe lens — question behind the question | 4 tiers: Demand Perspective, Question Behind the Question, Anomaly File, Hidden Isomorphisms |
| Bass Line task ID | task-1776460836220-3eyezz | Mon/Wed/Fri 4am ET (cron `0 8 * * 1,3,5`), full Taster pipeline, email to rmichelson@bwscampus.com |
| Bass Line persona | `taster/profiles/rob-michelson.json` | Substructure-depth scoring, earthy/Cuban palette, 4 sections |
| Bass Line template | `references/bass-line-template.html` | Garden green/tobacco/Cuban coral, Bitter + Lora, instrument dividers |
| Bass Line filter | Substructure lens — the game beneath the game | 4 tiers: Equilibrium Break, Power Ledger, Bayesian Update, Garden Note |
| MileZero task ID | task-1776373950083-zrqh97 | Wed+Fri 2am UTC, full Taster pipeline, email to robyn@milezero.io |
| Smoke Break task ID | smoke-break-1774414499 | Daily 1am UTC, Slack DM to Hamid (U086A9XFH43) |
| Signal fetch skill | `jotf-signal-fetch` | All pipelines MUST use Docker API `host.docker.internal:3000/api/daily-oracle?date=START&date_end=END`. NEVER WebSearch. |
| Docker API schema | `{exported_at, count, articles: [{date, company, title, theme, summary, tags (string), url}]}` | Tags = comma-separated string, not array. Split on ingest. |
