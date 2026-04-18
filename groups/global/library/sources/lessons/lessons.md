---
origin_channel: slack_main
---

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

### Large Slack Results — Sub-Agent Chunking (2026-04-02)
When Slack channel history exceeds token limits, results are saved to a file. Use Agent tool with sequential chunk-reading instructions (offset/limit on Read tool) to process the full file.

**Why**: Direct inline processing fails on large payloads. The sub-agent pattern lets us consume arbitrarily large results without context overflow.
