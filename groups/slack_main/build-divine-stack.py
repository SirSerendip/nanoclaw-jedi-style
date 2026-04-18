#!/usr/bin/env python3
"""
DIVINE ENTERPRISE STACK — Hand-tuned spatial SVG
Wrapped in JOTF brand system. Colors inspired by Hindu deity palette.
"""
import sys
sys.path.insert(0, '/workspace/ipc/files')
from jotf_svg_constants import build_svg, MAGENTA, MAGENTA_LIGHT, SLATE_300, SLATE_400, SLATE_500, SLATE_600, SLATE_700, EMERALD

W, H = 1800, 1200

# ─── DEITY COLORS (from reference image) ──────────────────────────────────
C_VISHNU    = '#E8722A'   # Warm orange
C_LAKSHMI   = '#D4A017'   # Gold
C_SHIVA     = '#7B3FA0'   # Purple
C_DEVI      = '#B07CC8'   # Lavender
C_BRAHMA    = '#1A8A7A'   # Teal
C_SARASVATI = '#3BB8A0'   # Light teal
C_GANESHA   = '#5CB338'   # Lime green
C_KALI      = '#2C2C2C'   # Charcoal
C_DURGA     = '#C93060'   # Deep magenta/rose
C_SKANDA    = '#D96030'   # Burnt orange
C_HUMANS    = '#6B7280'   # Neutral gray

# Cluster BG (muted versions)
def cluster_bg(c, opacity=0.08):
    return f'fill="{c}" opacity="{opacity}"'

# ─── HELPER: deity node (circle + label) ──────────────────────────────────
def deity_node(cx, cy, r, name, role, arms, tools, color, text_color='#F8FAFC'):
    # Glow
    glow = f'<circle cx="{cx}" cy="{cy}" r="{r+8}" fill="{color}" opacity="0.15"/>'
    circle = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}" stroke="{color}" stroke-width="2" opacity="0.9"/>'
    # Arms badge
    badge = f'<circle cx="{cx+r-4}" cy="{cy-r+4}" r="10" fill="#1A1520" stroke="{color}" stroke-width="1.5"/>'
    badge += f'<text x="{cx+r-4}" y="{cy-r+8}" text-anchor="middle" style="font-family:\'JetBrains Mono\',monospace;font-size:8px;font-weight:600;fill:{text_color}">{arms}</text>'
    # Name
    name_t = f'<text x="{cx}" y="{cy-4}" text-anchor="middle" style="font-family:\'Clash Display\',sans-serif;font-size:13px;font-weight:600;fill:{text_color};letter-spacing:0.05em">{name.upper()}</text>'
    # Role
    role_t = f'<text x="{cx}" y="{cy+10}" text-anchor="middle" style="font-family:\'Satoshi\',sans-serif;font-size:8.5px;fill:{text_color};opacity:0.85">{role}</text>'
    return f'{glow}\n{circle}\n{badge}\n{name_t}\n{role_t}'

def tools_label(x, y, tools_text, color='#94A3B8', max_width=180):
    """Small tools label below a node"""
    return f'<text x="{x}" y="{y}" text-anchor="middle" style="font-family:\'JetBrains Mono\',monospace;font-size:6.5px;fill:{color};letter-spacing:0.03em">{tools_text}</text>'

def cluster_box(x, y, w, h, label, color, opacity=0.06):
    rx = 12
    return f'''<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{color}" opacity="{opacity}" stroke="{color}" stroke-width="1" stroke-opacity="0.25"/>
<text x="{x+w/2}" y="{y+16}" text-anchor="middle" style="font-family:\'JetBrains Mono\',monospace;font-size:8px;font-weight:500;fill:{color};letter-spacing:0.12em;opacity:0.7">{label}</text>'''

def edge_arrow(x1, y1, x2, y2, label='', color='#94A3B8', dashed=False, opacity=0.5):
    """Directed edge with optional label"""
    dash = ' stroke-dasharray="6,4"' if dashed else ''
    mx, my = (x1+x2)/2, (y1+y2)/2
    line = f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="1.2" opacity="{opacity}"{dash} marker-end="url(#arrowhead)"/>'
    lbl = ''
    if label:
        lbl = f'<text x="{mx}" y="{my-5}" text-anchor="middle" style="font-family:\'JetBrains Mono\',monospace;font-size:6.5px;fill:{color};letter-spacing:0.04em">{label}</text>'
    return f'{line}\n{lbl}'

def consort_link(x1, y1, x2, y2, color='#EC4899', opacity=0.3):
    """Undirected collaboration link"""
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="1.5" opacity="{opacity}" stroke-dasharray="4,3"/>'

# ─── LAYOUT POSITIONS (spatial, matching original) ────────────────────────
# Vaikuntha.cloud — top center-right
V_CX, V_CY = 1050, 170      # Vishnu
L_CX, L_CY = 1280, 170      # Lakshmi

# Kailash.cluster — upper left
SH_CX, SH_CY = 380, 220     # Shiva
DE_CX, DE_CY = 530, 220     # Devi

# Brahmaloka.dev — lower left
BR_CX, BR_CY = 260, 440     # Brahma
SA_CX, SA_CY = 260, 560     # Sarasvati

# Gateway.node — center
GA_CX, GA_CY = 780, 480     # Ganesha

# Edge.cluster — bottom center
KA_CX, KA_CY = 660, 750     # Kali

# Fortress.layer — right
DU_CX, DU_CY = 1400, 440    # Durga

# WarRoom.compute — right lower
SK_CX, SK_CY = 1300, 680    # Skanda

# Human Interface — bottom
HU_CX, HU_CY = 900, 950     # Humans

# ─── BUILD CONTENT ────────────────────────────────────────────────────────
parts = []

# Arrowhead marker
parts.append('''<defs>
<marker id="arrowhead" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto" markerUnits="strokeWidth">
  <path d="M0,0 L8,3 L0,6" fill="#94A3B8" opacity="0.7"/>
</marker>
<marker id="arrowhead-warm" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto" markerUnits="strokeWidth">
  <path d="M0,0 L8,3 L0,6" fill="#E8722A" opacity="0.7"/>
</marker>
</defs>''')

# ── SUBTITLE ──
parts.append(f'<text x="{W/2}" y="108" text-anchor="middle" style="font-family:\'JetBrains Mono\',monospace;font-size:8px;fill:{SLATE_500};letter-spacing:0.2em">SPECULATIVE ORG-GRAPH · 99% AI WORKFORCE · DECENTRALIZED AUTHORITY · MYTHIC RUNTIME</text>')

# ── CLUSTER BOXES ──
parts.append(cluster_box(960, 118, 410, 120, 'Vaikuntha.cloud — Strategic Continuity Cluster', C_VISHNU))
parts.append(cluster_box(290, 168, 330, 120, 'Kailash.cluster — Transformation Sandbox', C_SHIVA))
parts.append(cluster_box(150, 380, 240, 240, 'Brahmaloka.dev — Architecture Layer', C_BRAHMA))
parts.append(cluster_box(670, 420, 230, 140, 'Gateway.node — Orchestration Layer', C_GANESHA))
parts.append(cluster_box(555, 690, 220, 140, 'Edge.cluster — Experimental Fork', C_KALI))
parts.append(cluster_box(1290, 370, 230, 170, 'Fortress.layer — Defense Layer', C_DURGA))
parts.append(cluster_box(1180, 610, 260, 160, 'WarRoom.compute — Expansion Layer', C_SKANDA))
parts.append(cluster_box(760, 900, 280, 100, 'Human Interface Layer — Peripheral Support', C_HUMANS))

# ── CONSORT LINKS (behind nodes) ──
parts.append(consort_link(V_CX, V_CY, L_CX, L_CY, C_VISHNU))
parts.append(consort_link(SH_CX, SH_CY, DE_CX, DE_CY, C_SHIVA))
parts.append(consort_link(BR_CX, BR_CY, SA_CX, SA_CY, C_BRAHMA))
parts.append(consort_link(GA_CX, GA_CY, L_CX, L_CY, C_GANESHA))
parts.append(consort_link(SK_CX, SK_CY, DU_CX, DU_CY, C_DURGA))
parts.append(consort_link(KA_CX, KA_CY, SH_CX, SH_CY, C_KALI))

# ── STRATEGIC FLOW EDGES ──
parts.append(edge_arrow(V_CX+30, V_CY, L_CX-35, L_CY, 'Quarterly OKRs', C_VISHNU, opacity=0.6))
parts.append(edge_arrow(V_CX-35, V_CY+10, SH_CX+35, SH_CY-10, 'Strategic Continuity', C_VISHNU, opacity=0.6))

parts.append(edge_arrow(L_CX, L_CY+35, GA_CX+30, GA_CY-35, 'Compute Allocation', C_LAKSHMI, opacity=0.5))
parts.append(edge_arrow(L_CX+30, L_CY+30, DU_CX-30, DU_CY-30, 'Capital Protection', C_LAKSHMI, opacity=0.5))

parts.append(edge_arrow(SH_CX-20, SH_CY+35, BR_CX+20, BR_CY-35, 'Sunset Legacy', C_SHIVA, opacity=0.5))
parts.append(edge_arrow(SH_CX+20, SH_CY+35, KA_CX-20, KA_CY-35, 'Trigger Disruption', C_SHIVA, dashed=True, opacity=0.5))

parts.append(edge_arrow(BR_CX+35, BR_CY+10, GA_CX-35, GA_CY-10, 'New Architecture', C_BRAHMA, opacity=0.5))
parts.append(edge_arrow(SA_CX+30, SA_CY-20, BR_CX+30, BR_CY+20, 'Knowledge Feed', C_SARASVATI, opacity=0.5))
parts.append(edge_arrow(SA_CX+30, SA_CY-40, V_CX-35, V_CY+30, 'Training Data', C_SARASVATI, opacity=0.4))

parts.append(edge_arrow(GA_CX+35, GA_CY+20, SK_CX-35, SK_CY-20, 'Deployment', C_GANESHA, opacity=0.5))
parts.append(edge_arrow(SK_CX-10, SK_CY-35, L_CX+10, L_CY+35, 'Market Expansion', C_SKANDA, opacity=0.5))

parts.append(edge_arrow(DU_CX-20, DU_CY-35, V_CX+20, V_CY+35, 'Risk Signals', C_DURGA, opacity=0.5))
parts.append(edge_arrow(DU_CX-10, DU_CY+35, SK_CX+10, SK_CY-20, 'Defense Protocol', C_DURGA, opacity=0.5))

parts.append(edge_arrow(KA_CX+20, KA_CY-35, V_CX-20, V_CY+35, 'Internal Cannibalization', C_KALI, dashed=True, opacity=0.5))
parts.append(edge_arrow(KA_CX+35, KA_CY-20, L_CX-20, L_CY+35, 'Radical Prototype', C_KALI, dashed=True, opacity=0.4))

# Human interface edges
parts.append(edge_arrow(HU_CX+30, HU_CY-35, L_CX, L_CY+35, 'Token Approval', C_HUMANS, opacity=0.4))
parts.append(edge_arrow(HU_CX+60, HU_CY-35, DU_CX-20, DU_CY+35, 'Ethical Escalation', C_HUMANS, opacity=0.4))
parts.append(edge_arrow(HU_CX-30, HU_CY-35, GA_CX, GA_CY+35, 'Edge Case Handling', C_HUMANS, opacity=0.4))

# ── DEITY NODES ──
parts.append(deity_node(V_CX, V_CY, 32, 'Vishnu', 'Chief Strategy Agent', '4', '', C_VISHNU))
parts.append(tools_label(V_CX, V_CY+52, 'Planning · Simulation · KPI · Risk', C_VISHNU))

parts.append(deity_node(L_CX, L_CY, 32, 'Lakshmi', 'Capital Allocation', '4', '', C_LAKSHMI))
parts.append(tools_label(L_CX, L_CY+52, 'Forecast · Allocation · Revenue · Liquidity', C_LAKSHMI))

parts.append(deity_node(SH_CX, SH_CY, 30, 'Shiva', 'Transformation', '3', '', C_SHIVA))
parts.append(tools_label(SH_CX, SH_CY+48, 'Legacy · Pruner · Restructure', C_SHIVA))

parts.append(deity_node(DE_CX, DE_CY, 22, 'Devi', 'Shakti Layer', '', '', C_DEVI))

parts.append(deity_node(BR_CX, BR_CY, 30, 'Brahma', 'Systems Architect', '4', '', C_BRAHMA))
parts.append(tools_label(BR_CX, BR_CY+48, 'Design · API · Org Opt · Knowledge', C_BRAHMA))

parts.append(deity_node(SA_CX, SA_CY, 28, 'Sarasvati', 'Knowledge Agent', '4', '', C_SARASVATI))
parts.append(tools_label(SA_CX, SA_CY+46, 'RAG · Search · Pattern · Curator', C_SARASVATI))

parts.append(deity_node(GA_CX, GA_CY, 34, 'Ganesha', 'Operations Agent', '4', '', C_GANESHA))
parts.append(tools_label(GA_CX, GA_CY+52, 'Workflow · Error · Ticket · Dependency', C_GANESHA))

parts.append(deity_node(KA_CX, KA_CY, 30, 'Kali', 'Radical Disruption', '∞', '', C_KALI))
parts.append(tools_label(KA_CX, KA_CY+48, 'All APIs (Experimental Mode)', '#6B7280'))

parts.append(deity_node(DU_CX, DU_CY, 34, 'Durga', 'Risk &amp; Defense', '10', '', C_DURGA))
parts.append(tools_label(DU_CX, DU_CY+52, 'Threat · Regulatory · Incident · Reputation', C_DURGA))
parts.append(tools_label(DU_CX, DU_CY+62, 'Crisis · Brand · Integrity · Access · Ethics · Stress', C_DURGA))

parts.append(deity_node(SK_CX, SK_CY, 30, 'Skanda', 'Market Expansion', '6', '', C_SKANDA))
parts.append(tools_label(SK_CX, SK_CY+48, 'CI · Sim · GTM · Campaign · Sentiment · Proto', C_SKANDA))

parts.append(deity_node(HU_CX, HU_CY, 28, 'Humans', 'Peripheral Support', '1%', '', C_HUMANS))
parts.append(tools_label(HU_CX, HU_CY+46, 'Handoffs · Ethical Escalation · Token Replenishment', '#6B7280'))

# ── SEMIOTIC KEY (bottom left) ──
key_x, key_y = 60, 830
parts.append(f'<text x="{key_x}" y="{key_y}" style="font-family:\'Clash Display\',sans-serif;font-size:10px;font-weight:600;fill:#F8FAFC;letter-spacing:0.1em">SEMIOTIC KEY</text>')
# Strategic flow
parts.append(f'<line x1="{key_x}" y1="{key_y+16}" x2="{key_x+40}" y2="{key_y+16}" stroke="#94A3B8" stroke-width="1.2" marker-end="url(#arrowhead)"/>')
parts.append(f'<text x="{key_x+50}" y="{key_y+20}" style="font-family:\'JetBrains Mono\',monospace;font-size:7px;fill:{SLATE_400}">Strategic flow (directed)</text>')
# Disruption
parts.append(f'<line x1="{key_x}" y1="{key_y+32}" x2="{key_x+40}" y2="{key_y+32}" stroke="#94A3B8" stroke-width="1.2" stroke-dasharray="6,4" marker-end="url(#arrowhead)"/>')
parts.append(f'<text x="{key_x+50}" y="{key_y+36}" style="font-family:\'JetBrains Mono\',monospace;font-size:7px;fill:{SLATE_400}">Disruption path</text>')
# Consort
parts.append(f'<line x1="{key_x}" y1="{key_y+48}" x2="{key_x+40}" y2="{key_y+48}" stroke="{MAGENTA}" stroke-width="1.5" stroke-dasharray="4,3" opacity="0.5"/>')
parts.append(f'<text x="{key_x+50}" y="{key_y+52}" style="font-family:\'JetBrains Mono\',monospace;font-size:7px;fill:{SLATE_400}">Consort (collaboration)</text>')
# Human interface
parts.append(f'<line x1="{key_x}" y1="{key_y+64}" x2="{key_x+40}" y2="{key_y+64}" stroke="{C_HUMANS}" stroke-width="1.2" marker-end="url(#arrowhead)"/>')
parts.append(f'<text x="{key_x+50}" y="{key_y+68}" style="font-family:\'JetBrains Mono\',monospace;font-size:7px;fill:{SLATE_400}">Human interface</text>')
# Notes
parts.append(f'<text x="{key_x}" y="{key_y+88}" style="font-family:\'JetBrains Mono\',monospace;font-size:6.5px;fill:{SLATE_500}">Arms = operational surface · Abode = runtime cluster</text>')
parts.append(f'<text x="{key_x}" y="{key_y+100}" style="font-family:\'JetBrains Mono\',monospace;font-size:6.5px;fill:{SLATE_500}">No CEO node — emergent authority · 99% AI · 1% human</text>')

# ── QUARTERLY CYCLE (bottom right) ──
qc_x, qc_y = 1480, 830
parts.append(f'<text x="{qc_x}" y="{qc_y}" style="font-family:\'Clash Display\',sans-serif;font-size:10px;font-weight:600;fill:#F8FAFC;letter-spacing:0.1em">QUARTERLY CYCLE</text>')
steps = [
    '1. Vishnu defines dharma (OKRs)',
    '2. Lakshmi reallocates compute',
    '3. Shiva decommissions legacy',
    '4. Brahma designs architecture',
    '5. Ganesha automates deploy',
    '6. Skanda executes expansion',
    '7. Durga defends',
    '8. Kali stress-tests via destruction',
    '9. Humans approve token expansion',
]
for i, step in enumerate(steps):
    parts.append(f'<text x="{qc_x}" y="{qc_y+16+i*13}" style="font-family:\'JetBrains Mono\',monospace;font-size:7px;fill:{SLATE_400}">{step}</text>')

# ── SHANTI PEACE ──
parts.append(f'<text x="{W/2}" y="{H-80}" text-anchor="middle" style="font-family:\'Satoshi\',sans-serif;font-size:9px;fill:{SLATE_500};font-style:italic;letter-spacing:0.1em">🕉 Shanti Peace 🕉</text>')

content_body = '\n'.join(parts)

svg = build_svg(
    title='DIVINE ENTERPRISE STACK',
    content_body=content_body,
    theme='dark',
    W=W, H=H,
    eyebrow='JEDI ORACLE · SPECULATIVE ORG-GRAPH · MYTHIC RUNTIME',
    subtitle='99% AI Workforce · Decentralized Authority · Polytheistic Architecture',
    sources='Concept: jedionthefly.com/oracle',
)

# ── POST-PROCESSING ──────────────────────────────────────────────────────

# 1. Creme interior background: insert a creme rect between header (y=80) and footer (y=H-60)
creme_rect = f'<rect x="0" y="84" width="{W}" height="{H-144}" fill="#FDF6EC" rx="0"/>'
svg = svg.replace('<!-- ═══ CONTENT AREA', f'{creme_rect}\n<!-- ═══ CONTENT AREA')

# 2. Lighten footer text so it's readable on dark background
svg = svg.replace(
    f"font-size:7.5px;fill:{SLATE_500};letter-spacing:0.05em\">SOURCES:",
    f"font-size:7.5px;fill:{SLATE_300};letter-spacing:0.05em\">SOURCES:"
)
svg = svg.replace(
    f"font-size:7.5px;fill:{SLATE_700};letter-spacing:0.05em\">Analysis generated",
    f"font-size:7.5px;fill:{SLATE_400};letter-spacing:0.05em\">Analysis generated"
)
# Also lighten the copyright line
svg = svg.replace(
    f"font-size:7.5px;fill:{MAGENTA};letter-spacing:0.05em\">© 2025",
    f"font-size:7.5px;fill:{MAGENTA_LIGHT};letter-spacing:0.05em\">© 2025"
)

# 3. Make "Jedi Oracle" in footer/header a genuine hyperlink
#    Wrap the jedionthefly.com/oracle references with <a> tags
svg = svg.replace(
    '© 2025 jedionthefly.com/oracle',
    '© 2025 <a href="https://jedionthefly.com/oracle">jedionthefly.com/oracle</a>'
).replace(
    'Concept: jedionthefly.com/oracle',
    'Concept: <a href="https://jedionthefly.com/oracle">jedionthefly.com/oracle</a>'
)

# 4. Fix semiotic key + quarterly cycle text colors for creme background
svg = svg.replace(
    f"font-size:10px;font-weight:600;fill:#F8FAFC;letter-spacing:0.1em\">SEMIOTIC KEY",
    f"font-size:10px;font-weight:600;fill:#1A1520;letter-spacing:0.1em\">SEMIOTIC KEY"
)
svg = svg.replace(
    f"font-size:10px;font-weight:600;fill:#F8FAFC;letter-spacing:0.1em\">QUARTERLY CYCLE",
    f"font-size:10px;font-weight:600;fill:#1A1520;letter-spacing:0.1em\">QUARTERLY CYCLE"
)
# Lighten semiotic key line labels and quarterly steps for creme bg
svg = svg.replace(f"font-size:7px;fill:{SLATE_400}", f"font-size:7px;fill:{SLATE_600}")
svg = svg.replace(f"font-size:6.5px;fill:{SLATE_500}", f"font-size:6.5px;fill:{SLATE_600}")

# 5. Fix node text colors for creme background (tools labels)
svg = svg.replace(f"font-size:6.5px;fill:#6B7280", f"font-size:6.5px;fill:#4B5563")

# 6. Fix subtitle text for creme
svg = svg.replace(f"font-size:8px;fill:{SLATE_500};letter-spacing:0.2em\">SPECULATIVE", f"font-size:8px;fill:{SLATE_600};letter-spacing:0.2em\">SPECULATIVE")

# 7. Fix Shanti Peace text for creme
svg = svg.replace(f"font-size:9px;fill:{SLATE_500};font-style:italic", f"font-size:9px;fill:{SLATE_600};font-style:italic")

# 8. Wrap Jedi Oracle eyebrow text as hyperlink
svg = svg.replace(
    f"fill:{EMERALD};letter-spacing:0.18em\">JEDI ORACLE",
    f"fill:{EMERALD};letter-spacing:0.18em\"><a href=\"https://jedionthefly.com/oracle\">JEDI ORACLE</a>"
)

out = '/workspace/group/divine-org-graph-branded.svg'
with open(out, 'w') as f:
    f.write(svg)
print(f"✅ Written: {out} ({len(svg)} chars)")
