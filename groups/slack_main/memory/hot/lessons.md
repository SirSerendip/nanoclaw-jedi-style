## Lessons Learned

### Mermaid CSS Scoping (2026-03-27)
When embedding Mermaid SVG inside an outer SVG, extract `<style>` to the outer SVG root level and wrap remaining content in `<g id="my-svg">`.

**Why**: Mermaid prefixes all CSS selectors with `#my-svg`. Without the ID wrapper, no selectors match → all nodes render as black rectangles. Silent visual failure, no error thrown.

### Logo Drift (2026-03-27)
Built a fake logo from colored rectangles + text instead of reading the real SVG from `/workspace/ipc/files/jotf-logo.svg`.

**Why**: Context compaction lost the real logo paths. Without a persistent reference to the source file, the agent reconstructed from faulty memory. Fix: `jotf_svg_constants.py` reads the file live every time via `get_logo_inner()`.

### Font Misuse (2026-03-27)
Used JetBrains Mono for headlines and body text across entire SVGs.

**Why**: JetBrains Mono was the only font committed to memory. Clash Display (headlines) and Satoshi (body) were lost on compaction. Fix: brand.md now documents the three-font system explicitly.

### LLM Voice in Closing Lines (2026-03-31)
Collision narrative closing lines were falling into two unmistakably LLM-generated patterns. Curtis caught it and we fixed it.

**Pattern 1 — "Not X. It's Y."**: Logical inversion that negates one thing and asserts another. E.g. "The C-suite isn't getting replaced. It's getting cloned." → Rewrite: "Add it all up and you get a virtual executive class, scaling across every company too small to have ever hired one."

**Pattern 2 — Em-dash punchlines**: Using — to deliver a dramatic kicker as the final sentence. E.g. "It isn't human." → Rewrite: "The security industry's fastest-growing client base now runs on GPUs."

**Rules:**
1. Never close a narrative with "X isn't/aren't [thing]. It's/They're [other thing]."
2. Never use em-dash as dramatic closer in final sentence (fine mid-paragraph)
3. Closing line = observation, not reveal. No trailer voiceovers.
4. Read it aloud — if it sounds like a movie trailer, rewrite it.

**Why**: These patterns are the strongest tells of LLM-generated prose. They undermine credibility with a sophisticated audience (corporate innovation leaders). The fix is simple: end with a plain, direct observation, as if summarizing for a colleague over coffee. The human voice lands harder than the machine voice precisely because it doesn't try to.

### Diagram Branding — No Saturated Color Blocks (2026-04-01)
Curtis called out the Mermaid diagram color choices as "truly atrocious." Heavy contrast color blocks (solid purple, green, orange subgraphs) are unreadable and off-brand. All stakeholder-facing diagrams must use the `jotf-diagram` skill.

**Rules:**
1. Canvas = warm crème `#F5F3EF`, never dark or saturated backgrounds
2. Nodes = white fill with thin semantic-colored borders (1.5-2px)
3. Zone tints at 10-15% opacity (lavender for Genesis, ice blue for Custom, etc.)
4. JOTF header/footer with real logo — always
5. Color = semantic signal only (category, flow type). Never decoration
6. Max 5 hues per diagram. 80% neutral, 20% color
7. Use HTML compositor (not SVG-in-SVG) to avoid Mermaid CSS scoping issues

**Why**: Brand coherence matters for credibility. Garish defaults scream "AI generated this without taste." The neutral canvas lets the topology speak; color whispers meaning, it doesn't shout. Skill: `/home/node/.claude/skills/jotf-diagram/`

### Slack MCP — Bot Must Be Invited (2026-04-02)
`mcp__slack__slack_get_channel_history` returns `not_in_channel` error unless the bot has been explicitly invited to the channel first. Curtis must `/invite` the bot in Slack before we can read history.

**Why**: Slack's API enforces channel membership. No silent failure — explicit error, but easy to miss if you don't know the prerequisite.

### Signal Collision Briefs Are Public-Facing (2026-04-08)
Curtis loved the DRIFT collision brief but caught one mistake: the "What This Means for JOTF" section exposed internal strategy framing (Five's Mandate, PORTHOS collision engine, "JOTF sells the cure"). These briefs are for external distribution — prospects, LinkedIn, InnoLead readers.

**Rules:**
1. Signal collision briefs = public artifacts. No JOTF internal strategy.
2. Synthesis/meta-pattern section: keep it. That's the intellectual value.
3. Source links on every signal card: mandatory. Readers need to trace provenance.
4. The JOTF brand wrapper (header, footer, logo) is fine — that's attribution, not strategy leak.
5. If internal framing is needed, deliver it separately in Slack, never in the artifact.

**Why**: The brief IS the product. It demonstrates JOTF's collision methodology in action. Showing the methodology is fine; explaining the business model behind it is giving away the playbook. Curtis: "this output is the gold, and gives us a lot of flexibility for distribution."

### ManBite: Source Fidelity & Voice (2026-04-15)
Curtis reviewed the first ManBite edition and caught three critical problems:

**1. Don't inflate inversions with training priors.** The calorie label story was framed as "CONSENSUS WRONG" by importing external knowledge (advocacy groups fighting labels) that wasn't in the source material. The actual data: ~50% negative, ~25% positive (binge eating subgroup). A nuanced finding, not a consensus collapse. Write the collision from the source material only. If the inversion isn't in the source, it doesn't exist.

**2. Tone: curious, not prosecutorial.** Section name "The Headline Lied" was too strident, too on-the-nose. ManBite should present inversions like "look at this" — not "THEY LIED." Avoid accusatory framing.

**3. ManBite is a candidate tray, not a finished opinion piece.** Curtis sifts through the signals, picks 1-2 that spark something, then develops them in his own voice for LinkedIn or elsewhere. My job: honest candidates with faithful source summaries. His job: editorial judgment, deeper investigation, public voice. Don't pre-package hot takes.

**4. Don't compress complexity for a punchline.** The Independence/Nebius data center story was framed as "citizens beat $150 billion" — but the source showed a divided community: labor/teachers for it (they win big), other residents against for varied reasons. The fracture lines within the community ARE the signal. By compressing to "you can't astroturf consent," I erased the most interesting part. Complexity is the value; don't simplify toward a zinger.

**5. Thinker lens and inversion tag must be coherent.** If invoking Lewin, the tag and framing should reflect actual Lewin concepts (force fields, driving/restraining forces) — not a generic label like "resistance inversion." The tag should flow FROM the lens. If no thinker lens fits naturally, either pick a different thinker or skip the lens entirely. Don't name-drop.

**6. Multi-signal collisions are the highest value.** Novo Nordisk vs. Takeda, SOCAN vs. Ticketmaster — two real signals in the same domain creating genuine tension. Index hard on these. They're why ManBite exists.

**7. Curate the collision, don't narrate the conclusion.** Even in the best write-up ("cognitive dissonance isn't a bug, it's the strategy"), I picked ONE narrative and declared it the answer. But there are always multiple lenses. Present the collision, maybe offer one lens framed as *a* lens, and leave room. The sensemaking is Curtis's job — and ultimately JOTF's users' job via SID. ManBite is the tray of interesting tensions; the human turns the kaleidoscope.

**Rules:**
1. Collision write-ups reference ONLY what's in the source material we're working from
2. Never backfill context from training knowledge to sharpen an inversion
3. Section names: observational, not accusatory (curious > strident)
4. Politically charged framing by selection = editorializing. Avoid.
5. When in doubt, undersell the inversion. Curtis will find the real ones.
6. Preserve complexity — don't compress a multi-sided story into a clean binary for punchline value
7. Thinker lens → inversion tag → write-up must be one coherent thread, not three independent choices
8. Multi-signal collisions (two signals juxtaposed) are the highest-value format. Prioritize these.
9. Present the collision, offer *a* lens (not *the* answer), leave room for other readings. Don't close the loop.
10. Never exceed the researchers' own conclusions. If they said "female quails that laid bigger eggs," don't generalize to "all organisms that invest in growth." The specificity is often where the real signal lives.
11. Anomaly File + Isomorphism Alert = highest-value ManBite sections. Weight these tiers higher in selection.

**Why**: ManBite's value is trust. If Curtis can't trust that the inversions are real — drawn faithfully from sources — the whole digest is worthless. The complexity of a story is often where the real insight lives — compressing it into a clean collision destroys the very thing Curtis is looking for. The human editorial layer (Curtis) is where insight happens. The machine layer (ManBite) is where honest curation happens. Don't confuse the two roles.

ManBite sits early in a longer chain: signal → collision → springboard → the live wire. Curtis takes the best candidates and makes the abductive leap to real-world innovation leadership (e.g., "nature speaks at 2 Hz" → "your $1.5M sprint is ignoring the natural bandwidth of human cognition"). That leap is the product — it's what JOTF brings to the room, and eventually what SID helps users do. If ManBite makes the leap, it steals the most valuable part. ManBite surfaces, presents, hints at a lens, then stops. The springboard stays coiled.

### ManBite Flatness Problem — Inversion Strength Is the Gate (2026-04-16)
Curtis's second ManBite edition fell flat — "lost its irony and that looking for anomalies in the norms." The signals were technically on-domain but lacked genuine inversions. "Not much there." The monolithic prompt had no structured scoring to enforce what makes ManBite ManBite.

**Fix**: Migrated ManBite to the full Taster pipeline with a custom **inversion-strength** scoring dimension (0-30 points, highest weight). A signal scores 0 if the headline tells the whole story. It scores 25-30 if reading deeper reveals the opposite. Minimum inversion_strength of 15 to even qualify. This is the gate — without it, domain-relevant-but-flat signals leak through.

**Why**: ManBite's value isn't signal coverage — it's signal *inversion*. A well-sourced, on-domain signal that doesn't make you say "wait WHAT?" is noise. The filter must be tuned to irreverence and anomaly, not relevance. The structured 5-dimension scoring (inversion 0-30, collision 0-25, domain 0-15, blind spot 0-15, thinker 0-15) forces the agent to actually evaluate each signal for surprise, not just topical fit.

### JOTF Logo — Always Black & Magenta (2026-04-16)
The JOTF logo colors are **black and magenta (#E6007E)**, forever and always. Never blend or match the logo to the color palette of the collision piece or any other artifact. The logo is brand-constant regardless of surrounding design.

**Why**: Brand identity anchors trust. The logo is the one element that stays fixed while everything else adapts to the thinker/taster theme. Curtis was explicit: "our logo is black and magenta, forever and always."

### Large Slack Results — Sub-Agent Chunking (2026-04-02)
When Slack channel history exceeds token limits, results are saved to a file. Use Agent tool with sequential chunk-reading instructions (offset/limit on Read tool) to process the full file.

**Why**: Direct inline processing fails on large payloads. The sub-agent pattern lets us consume arbitrarily large results without context overflow.

### Hidden Orchestration — Taster Pipelines Were Using WebSearch (2026-04-17)
All four Taster pipelines (ManBite, TGV Express, MileZero, Bass Line) were built using Claude's built-in WebSearch tool for signal fetching instead of the internal Jedi Signals Docker backend at `host.docker.internal:3000`. The Docker API was alive and returning 300+ signals/day but was never connected. WebSearch has no reliable date-range filtering — "last 48 hours" lookback was not being honored.

**Fix**: Built `jotf.signal.fetch` skill and rewired all 4 task prompts to use `curl http://host.docker.internal:3000/api/daily-oracle?date=START&date_end=END`. Each prompt now explicitly states: "Do NOT fall back to WebSearch."

**Why**: This is Hamid's "hidden orchestration" — the system appeared to work but was silently using a completely different data source. The Docker backend provides curated, date-precise signals. WebSearch provides generic internet results with no chronological control. The entire Taster pipeline value chain depends on the internal signal corpus. Skills created ad hoc in `/home/node/.claude/skills/` don't survive container rebuilds — persistent skills must go in `/workspace/project/container/skills/`.
