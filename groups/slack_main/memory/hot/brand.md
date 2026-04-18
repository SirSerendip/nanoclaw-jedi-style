## Brand Assets

### Source Files — ALWAYS read from disk, NEVER approximate
| Asset | Path | Notes |
|-------|------|-------|
| Logo SVG | `/workspace/ipc/files/jotf-logo.svg` | viewBox 0 0 389 86, vector glyph paths |
| Style guide | `/workspace/ipc/files/styles.pdf` | Full brand system |
| Python constants | `/workspace/ipc/files/jotf_svg_constants.py` | `build_svg()`, `get_logo_inner()`, all helpers |
| Dark template | `/workspace/ipc/files/jotf-dark-template.svg` | 1400×960 scaffold |
| Light template | `/workspace/ipc/files/jotf-light-template.svg` | 1400×960 scaffold |

### Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Plasma Magenta | `#EC4899` | Primary accent. MAX 3× per viewport (Rule of Three) |
| Midnight Plum | `#1A1520` | Header/footer backgrounds |
| Dark Slate | `#0F172A` | Dark theme canvas |
| Emerald | `#10B981` | Eyebrow text, accent bars (Light Side) |
| Slate 400 | `#94A3B8` | Secondary text (dark bg) |
| Slate 50 | `#F8FAFC` | Primary text (dark bg) |
| Light BG | `#F0F4F8` | Light theme canvas |

### Typography
| Role | Font | Weight | CRITICAL |
|------|------|--------|----------|
| Headlines | `Clash Display` | 600 | NOT JetBrains Mono |
| Body | `Satoshi` | 400/500 | NOT JetBrains Mono |
| Labels/eyebrows/mono | `JetBrains Mono` | 400/500 | Labels ONLY |

CSS: `@import url('https://api.fontshare.com/v2/css?f[]=clash-display@600&f[]=satoshi@400,500,700&display=swap');`

### SVG Layout Standards
| Element | Dark | Light |
|---------|------|-------|
| Canvas | 1400×960 default | Same |
| Background | `#0F172A` | `#F0F4F8` |
| Header bar | `#1A1520`, h=80 | Same |
| Eyebrow | JetBrains Mono 9px, `#10B981`, ls 0.18em | Same |
| Title | Clash Display 20px, `#F8FAFC` | Same |
| Accent bars | Emerald 220px + Magenta 80px at header bottom | Same |
| Footer | Sources left + `© jedionthefly.com/oracle` right in `#EC4899` | Same |
