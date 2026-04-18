<?php
require_once __DIR__ . '/../includes/data-config.php';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?php echo htmlspecialchars($edition['metaTitle']); ?></title>
<meta name="description" content="<?php echo htmlspecialchars($edition['metaDescription']); ?>">
<meta property="og:title" content="<?php echo htmlspecialchars($edition['ogTitle']); ?>">
<meta property="og:description" content="<?php echo htmlspecialchars($edition['ogDescription']); ?>">
<meta property="og:type" content="article">
<meta property="og:url" content="<?php echo htmlspecialchars('https://jedionthefly.com/collisions/' . $edition['slug'] . '.php'); ?>">
<link rel="preconnect" href="https://api.fontshare.com">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://api.fontshare.com/v2/css?f[]=clash-display@600&f[]=satoshi@400,500,700&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
/* ═══════════════════════════════════════════════════════════════════
   JOTF BRAND SYSTEM — Enterprise+AI Signal Collisions
   "Je transforme le bruit en décision" — PORTHOS
   ═══════════════════════════════════════════════════════════════════ */

:root {
  --magenta: #EC4899;
  --magenta-light: #F472B6;
  --magenta-dark: #DB2777;
  --midnight-plum: #1A1520;
  --dark-slate: #0F172A;
  --slate-800: #1E293B;
  --slate-700: #334155;
  --slate-600: #475569;
  --slate-500: #64748B;
  --slate-400: #94A3B8;
  --slate-300: #CBD5E1;
  --slate-200: #E2E8F0;
  --slate-100: #F1F5F9;
  --slate-50: #F8FAFC;
  --emerald: #10B981;
  --amber: #D97706;
  --creme: #FDF6EC;
  /* Collision accent colors */
  --collision-1: #EC4899; /* magenta — invisible c-suite */
  --collision-2: #10B981; /* emerald — infrastructure */
  --collision-3: #7B3FA0; /* violet — security */
  --collision-4: #3BB8A0; /* teal — healthcare */
  --collision-5: #D97706; /* amber — token economy */
  --collision-6: #E8722A; /* orange — kinetic agents */
  --collision-7: #5CB338; /* green — workforce */
}

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; }

body {
  background: var(--creme);
  color: var(--slate-700);
  font-family: 'Satoshi', sans-serif;
  font-weight: 400;
  line-height: 1.7;
  overflow-x: hidden;
}

/* ─── TYPOGRAPHY ─────────────────────────────────────────── */
h1, h2, h3, h4 {
  font-family: 'Clash Display', sans-serif;
  font-weight: 600;
  color: var(--midnight-plum);
  line-height: 1.2;
}
.mono {
  font-family: 'JetBrains Mono', monospace;
  font-weight: 400;
}
a { color: var(--magenta-dark); text-decoration: none; transition: color 0.2s; }
a:hover { color: var(--magenta); text-decoration: underline; }

/* ─── ANIMATIONS ─────────────────────────────────────────── */
@keyframes emerge {
  from { opacity: 0; transform: translateY(24px); }
  to { opacity: 1; transform: translateY(0); }
}
@keyframes pulse-glow {
  0%, 100% { opacity: 0.4; }
  50% { opacity: 1; }
}
@keyframes slide-in-left {
  from { opacity: 0; transform: translateX(-40px); }
  to { opacity: 1; transform: translateX(0); }
}
@keyframes count-pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.05); }
}

.reveal {
  opacity: 0;
  transform: translateY(40px);
  transition: opacity 0.8s ease, transform 0.8s ease;
}
.reveal.visible {
  opacity: 1;
  transform: translateY(0);
}
.reveal-delay-1 { transition-delay: 0.12s; }
.reveal-delay-2 { transition-delay: 0.24s; }
.reveal-delay-3 { transition-delay: 0.36s; }
.reveal-delay-4 { transition-delay: 0.48s; }

/* ─── HERO BUG ──────────────────────────────────────────── */
.hero-bug {
  margin: 0 auto 1.5rem;
  width: 80px;
  height: 80px;
  animation: emerge 0.8s ease both;
}
.hero-bug__svg {
  display: block;
  animation: bugSpin 20s linear infinite;
}
@keyframes bugSpin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* Node pulse — scale from each node's center */
.hero-bug__svg .node--catalyst {
  transform-origin: 58px 32px;
  animation: nodeGrow 3s ease-in-out infinite;
}
.hero-bug__svg .node--app {
  transform-origin: 30px 55px;
  animation: nodeGrow 3s ease-in-out 0.8s infinite;
}
.hero-bug__svg .node--tech {
  transform-origin: 78px 58px;
  animation: nodeGrow 3s ease-in-out 1.6s infinite;
}
.hero-bug__svg .node--trend {
  transform-origin: 45px 78px;
  animation: nodeGrow 4s ease-in-out 2.4s infinite;
}
@keyframes nodeGrow {
  0%, 100% { transform: scale(1); opacity: 0.8; }
  50% { transform: scale(1.35); opacity: 1; }
}

/* Bridge glow — lines brighten in sequence */
.hero-bug__svg .bridge--1 {
  animation: bridgeGlow 4s ease-in-out infinite;
}
.hero-bug__svg .bridge--2 {
  animation: bridgeGlow 4s ease-in-out 1.3s infinite;
}
.hero-bug__svg .bridge--3 {
  animation: bridgeGlow 4s ease-in-out 2.6s infinite;
}
@keyframes bridgeGlow {
  0%, 100% { opacity: 0.4; }
  50% { opacity: 1; }
}

/* ─── HERO ───────────────────────────────────────────────── */
.hero {
  padding: 5rem 2rem 4rem;
  text-align: center;
  position: relative;
  overflow: hidden;
  background: var(--midnight-plum);
}
.hero-eyebrow {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.7rem;
  letter-spacing: 0.2em;
  text-transform: uppercase;
  color: var(--emerald);
  margin-bottom: 1.2rem;
  animation: emerge 0.8s ease both;
}
.hero h1 {
  font-size: clamp(2.2rem, 5vw, 3.8rem);
  color: var(--slate-50);
  margin-bottom: 0.6rem;
  animation: emerge 0.8s ease 0.15s both;
}
.hero h1 .accent { color: var(--magenta); }
.hero .subtitle {
  font-size: clamp(1rem, 2.5vw, 1.35rem);
  color: var(--slate-300);
  font-weight: 400;
  max-width: 700px;
  margin: 0 auto 2rem;
  animation: emerge 0.8s ease 0.3s both;
}
.hero .edition-tag {
  display: inline-block;
  font-family: 'JetBrains Mono', monospace;
  font-size: 1.1rem;
  letter-spacing: 0.1em;
  color: var(--magenta-light);
  border: 1px solid var(--magenta);
  padding: 8px 20px;
  border-radius: 4px;
  animation: emerge 0.8s ease 0.45s both;
}

/* ─── SCROLL HINT ───────────────────────────────────────── */
.scroll-hint {
  position: absolute;
  bottom: 1.5rem;
  left: 50%;
  transform: translateX(-50%);
  color: var(--slate-400);
  animation: scrollBounce 2s ease-in-out infinite;
}
@keyframes scrollBounce {
  0%, 100% { transform: translateX(-50%) translateY(0); opacity: 0.4; }
  50% { transform: translateX(-50%) translateY(8px); opacity: 1; }
}

/* ─── STATS BAR ──────────────────────────────────────────── */
.stats-bar {
  display: flex;
  justify-content: center;
  flex-wrap: wrap;
  gap: 2rem;
  padding: 2rem;
  margin: 0 auto;
  max-width: 900px;
}
.stat-item {
  text-align: center;
}
.stat-number {
  font-family: 'Clash Display', sans-serif;
  font-size: 2rem;
  font-weight: 600;
  color: var(--magenta);
  display: block;
}
.stat-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6rem;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: var(--slate-600);
}

/* ─── MANIFESTO ──────────────────────────────────────────── */
.manifesto {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem 2rem 4rem;
  text-align: center;
}
.manifesto p {
  font-size: 1.15rem;
  color: var(--slate-600);
  line-height: 1.8;
}
.manifesto p strong { color: var(--midnight-plum); font-weight: 700; }
.manifesto .highlight { color: var(--magenta-dark); }

/* ─── DIVIDER ────────────────────────────────────────────── */
.section-divider {
  max-width: 900px;
  margin: 0 auto;
  padding: 0 2rem;
  display: flex;
  align-items: center;
  gap: 1rem;
}
.section-divider .line {
  flex: 1;
  height: 1px;
  background: linear-gradient(90deg, transparent, var(--slate-300), transparent);
}
.section-divider .diamond {
  width: 8px; height: 8px;
  transform: rotate(45deg);
  background: var(--magenta);
  flex-shrink: 0;
}

/* ─── COLLISION SECTION ──────────────────────────────────── */
.collision-section {
  max-width: 960px;
  margin: 0 auto;
  padding: 4rem 2rem;
}
.collision-header {
  display: flex;
  align-items: flex-start;
  gap: 1.5rem;
  margin-bottom: 2rem;
}
.collision-number {
  font-family: 'Clash Display', sans-serif;
  font-size: 3.5rem;
  font-weight: 600;
  line-height: 1;
  flex-shrink: 0;
  opacity: 0.25;
}
.collision-title-block {
  flex: 1;
}
.collision-eyebrow {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6rem;
  letter-spacing: 0.2em;
  text-transform: uppercase;
  margin-bottom: 0.4rem;
}
.collision-title {
  font-size: clamp(1.5rem, 3vw, 2rem);
  margin-bottom: 0.5rem;
}
.collision-subtitle {
  font-size: 0.95rem;
  color: var(--slate-500);
  font-style: italic;
}

/* Now / What's Next blocks */
.now-next-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  margin: 2rem 0;
}
@media (max-width: 700px) {
  .now-next-grid { grid-template-columns: 1fr; }
}
.now-block, .next-block {
  border-radius: 8px;
  padding: 1.8rem;
  position: relative;
}
.now-block {
  background: #fff;
  border-left: 3px solid var(--emerald);
}
.next-block {
  background: #fff;
  border-left: 3px solid var(--magenta);
}
.block-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6rem;
  letter-spacing: 0.2em;
  text-transform: uppercase;
  margin-bottom: 0.8rem;
  display: block;
}
.now-block .block-label { color: var(--emerald); }
.next-block .block-label { color: var(--magenta); }
.now-block p, .next-block p {
  font-size: 0.95rem;
  color: var(--slate-600);
  line-height: 1.7;
}
.now-block p strong, .next-block p strong { color: var(--midnight-plum); }

/* Narrative body */
.collision-narrative {
  font-size: 1.05rem;
  color: var(--slate-600);
  line-height: 1.8;
  margin-bottom: 2rem;
}
.collision-narrative strong { color: var(--midnight-plum); }

/* Signal list */
.signal-cards {
  display: flex;
  flex-direction: column;
  gap: 0;
  margin-top: 2rem;
}
.signal-cards::before {
  content: 'Supporting Headlines';
  display: block;
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6rem;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: var(--slate-400);
  margin-bottom: 0.4rem;
  padding-left: 22px;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%2394A3B8' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-2-2v-9c0-1.1.9-2 2-2h2'/%3E%3Cpath d='M18 14h-8'/%3E%3Cpath d='M15 18h-5'/%3E%3Cpath d='M10 6h8v4h-8V6Z'/%3E%3C/svg%3E");
  background-size: 16px 16px;
  background-repeat: no-repeat;
  background-position: left center;
}
.signal-card {
  display: block;
  padding: 0.75rem 0;
  border-top: 1px solid var(--slate-200);
  background: none;
  border-radius: 0;
}
.signal-card:hover {
  background: none;
  transform: none;
  box-shadow: none;
}
.signal-card .source {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.55rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--slate-400);
  margin-bottom: 0.15rem;
}
.signal-card .card-title {
  font-family: 'Clash Display', sans-serif;
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--midnight-plum);
  margin-bottom: 0.2rem;
  line-height: 1.3;
}
.signal-card .card-title a {
  color: var(--midnight-plum);
  text-decoration: none;
  transition: color 0.2s;
}
.signal-card .card-title a:hover {
  color: var(--magenta-dark);
}
.signal-card .card-summary {
  font-size: 0.8rem;
  color: var(--slate-500);
  line-height: 1.5;
}
/* card-link removed — headline is the link */

/* Color-coded card accents by collision */
/* Color-coded card accents removed — signal items are now a flat list */

.collision-1 .collision-number { color: var(--collision-1); }
.collision-2 .collision-number { color: var(--collision-2); }
.collision-3 .collision-number { color: var(--collision-3); }
.collision-4 .collision-number { color: var(--collision-4); }
.collision-5 .collision-number { color: var(--collision-5); }
.collision-6 .collision-number { color: var(--collision-6); }
.collision-7 .collision-number { color: var(--collision-7); }

.collision-1 .collision-eyebrow { color: var(--collision-1); }
.collision-2 .collision-eyebrow { color: var(--collision-2); }
.collision-3 .collision-eyebrow { color: var(--collision-3); }
.collision-4 .collision-eyebrow { color: var(--collision-4); }
.collision-5 .collision-eyebrow { color: var(--collision-5); }
.collision-6 .collision-eyebrow { color: var(--collision-6); }
.collision-7 .collision-eyebrow { color: var(--collision-7); }

/* ─── FRONTIER SCIENCE ───────────────────────────────────── */
.frontier-section {
  max-width: 960px;
  margin: 0 auto;
  padding: 4rem 2rem;
}
.frontier-intro {
  text-align: center;
  margin-bottom: 3rem;
}
.frontier-intro h2 {
  font-size: clamp(1.6rem, 3vw, 2.2rem);
  margin-bottom: 0.6rem;
}
.frontier-intro p {
  color: var(--slate-500);
  font-size: 1rem;
  max-width: 600px;
  margin: 0 auto;
}
.frontier-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.2rem;
}
.frontier-card {
  background: #fff;
  border: 1px solid var(--slate-200);
  border-radius: 8px;
  padding: 1.5rem;
  transition: border-color 0.3s, transform 0.2s, box-shadow 0.3s;
  border-left: 3px solid var(--amber);
}
.frontier-card:hover {
  border-color: var(--slate-300);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.06);
}
.frontier-card .card-category {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.55rem;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: var(--amber);
  margin-bottom: 0.5rem;
}
.frontier-card .card-title {
  font-family: 'Clash Display', sans-serif;
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--midnight-plum);
  line-height: 1.3;
  margin-bottom: 0.5rem;
}
.frontier-card .card-title a { color: var(--midnight-plum); }
.frontier-card .card-title a:hover { color: var(--amber); }
.frontier-card .card-summary {
  font-size: 0.8rem;
  color: var(--slate-500);
  line-height: 1.5;
}

/* ─── UTILITIES ──────────────────────────────────────────── */
.container { max-width: 960px; margin: 0 auto; padding: 0 2rem; }
.spacer-sm { height: 2rem; }
.spacer-md { height: 4rem; }
.spacer-lg { height: 6rem; }

@media (max-width: 600px) {
  .collision-header { flex-direction: column; gap: 0.5rem; }
  .collision-number { font-size: 2.5rem; }
  .stats-bar { gap: 0.8rem 1.2rem; padding: 1rem; }
  .stat-number { font-size: 1.5rem; }
  .hero { padding: 2rem 1.5rem 1.5rem; }
  .hero-bug { margin-bottom: 0.75rem; width: 56px; height: 56px; }
  .hero-bug__svg { width: 56px; height: 56px; }
  .hero .subtitle { margin-bottom: 1rem; }
  .manifesto { padding: 1rem 1.5rem 2rem; }
  .collision-section { padding: 3rem 1.5rem; }
}
</style>

<!-- Site nav + theme CSS -->
<link rel="stylesheet" href="/data/cache/themes.css?v=collisions">
<link rel="stylesheet" href="/assets/css/bem-frontend.css">

<!-- Override site CSS for collision page layout -->
<style>
  section.hero { display: block; text-align: center; padding: 5rem 2rem 4rem !important; }
  .hero * { text-align: center; }
  .hero h1 { display: block; width: 100%; }
  .hero .subtitle { display: block; width: 100%; margin-left: auto; margin-right: auto; }
  .hero .hero-eyebrow { display: block; width: 100%; }
  .hero .edition-tag { display: inline-block; }
  .stats-bar { display: flex !important; flex-direction: row !important; justify-content: center !important; flex-wrap: wrap !important; }
  .stat-item { text-align: center; }
  .section-divider { display: flex !important; flex-direction: row !important; align-items: center !important; }
  .now-next-grid { display: grid !important; grid-template-columns: 1fr 1fr !important; }
  .collision-header { display: flex !important; flex-direction: row !important; align-items: flex-start !important; }
  .signal-cards { display: flex !important; flex-direction: column !important; }
  .signal-card { display: block !important; }
  .frontier-grid { display: grid !important; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)) !important; }
  @media (max-width: 700px) {
    .now-next-grid { grid-template-columns: 1fr !important; }
  }
</style>
</head>
<body>

<?php include __DIR__ . '/../includes/nav.php'; ?>

<!-- ═══════════════════════════════════════════════════════════════════
     HERO
     ═══════════════════════════════════════════════════════════════════ -->
<section class="hero">
  <div class="hero-bug">
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="80" height="80" class="hero-bug__svg">
      <line x1="58" y1="32" x2="69.5" y2="24" stroke="#F472B6" stroke-width="2" stroke-linecap="round" opacity="0.6"/>
      <line x1="30" y1="55" x2="21.3" y2="63.7" stroke="#F472B6" stroke-width="2" stroke-linecap="round" opacity="0.5"/>
      <line x1="30" y1="55" x2="58" y2="32" stroke="#F472B6" stroke-width="2.5" stroke-linecap="round" opacity="0.7" class="bridge bridge--1"/>
      <line x1="58" y1="32" x2="78" y2="58" stroke="#F472B6" stroke-width="2" stroke-linecap="round" opacity="0.6" class="bridge bridge--2"/>
      <line x1="78" y1="58" x2="45" y2="78" stroke="#A78BFA" stroke-width="1.5" stroke-linecap="round" opacity="0.5" stroke-dasharray="3,4" class="bridge bridge--3"/>
      <line x1="30" y1="55" x2="78" y2="58" stroke="#F472B6" stroke-width="1.2" stroke-linecap="round" opacity="0.35"/>
      <circle cx="58" cy="32" r="8" fill="#EC4899" opacity="1" class="node node--catalyst"/>
      <circle cx="30" cy="55" r="6" fill="#EC4899" opacity="0.9" class="node node--app"/>
      <circle cx="78" cy="58" r="5.5" fill="#EC4899" opacity="0.8" class="node node--tech"/>
      <circle cx="45" cy="78" r="4.5" fill="#A78BFA" opacity="0.8" class="node node--trend"/>
    </svg>
  </div>
  <h1>The Now <span class="accent">&</span> the Next</h1>
  <p class="subtitle">
    Frontier science meets business strategy. A bi-weekly speculative fiction suggesting the shape of things to come.
  </p>
  <span class="edition-tag mono"><?php echo htmlspecialchars($edition['dateRange']); ?> Edition</span>
  <div class="scroll-hint" aria-hidden="true">
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <polyline points="6 9 12 15 18 9"></polyline>
    </svg>
  </div>
</section>

<!-- ═══════════════════════════════════════════════════════════════════
     STATS BAR
     ═══════════════════════════════════════════════════════════════════ -->
<div class="stats-bar reveal">
<?php foreach ($edition['stats'] as $stat): ?>
  <div class="stat-item">
    <span class="stat-number"><?php echo htmlspecialchars($stat['number']); ?></span>
    <span class="stat-label mono"><?php echo htmlspecialchars($stat['label']); ?></span>
  </div>
<?php endforeach; ?>
</div>

<!-- ═══════════════════════════════════════════════════════════════════
     MANIFESTO
     ═══════════════════════════════════════════════════════════════════ -->
<div class="manifesto reveal">
  <p>
    <?php echo $edition['manifesto']; ?>
  </p>
</div>

<div class="section-divider reveal">
  <div class="line"></div>
  <div class="diamond"></div>
  <div class="line"></div>
</div>


<?php foreach ($edition['collisions'] as $i => $collision): ?>
<?php $num = $i + 1; ?>
<!-- ═══════════════════════════════════════════════════════════════════
     COLLISION <?php echo $num; ?>

     ═══════════════════════════════════════════════════════════════════ -->
<section class="collision-section collision-<?php echo $num; ?> reveal">
  <div class="collision-header">
    <div class="collision-number"><?php echo str_pad($num, 2, '0', STR_PAD_LEFT); ?></div>
    <div class="collision-title-block">
      <div class="collision-eyebrow mono">Signal Collision</div>
      <h2 class="collision-title"><?php echo $collision['title']; ?></h2>
      <p class="collision-subtitle"><?php echo $collision['subtitle']; ?></p>
    </div>
  </div>

  <p class="collision-narrative">
    <?php echo $collision['narrative']; ?>

  </p>

  <div class="now-next-grid">
    <div class="now-block">
      <span class="block-label">⚡ The Now</span>
      <p><?php echo $collision['now']; ?></p>
    </div>
    <div class="next-block">
      <span class="block-label">→ What's Next</span>
      <p><?php echo $collision['next']; ?></p>
    </div>
  </div>

  <div class="signal-cards">
<?php foreach ($collision['signals'] as $signal): ?>
    <div class="signal-card">
      <div class="source mono"><?php echo htmlspecialchars($signal['source']); ?></div>
      <div class="card-title"><a href="<?php echo htmlspecialchars($signal['url']); ?>" target="_blank"><?php echo htmlspecialchars($signal['title']); ?></a></div>
      <div class="card-summary"><?php echo htmlspecialchars($signal['summary']); ?></div>
    </div>
<?php endforeach; ?>
  </div>
</section>

<?php if ($num < count($edition['collisions'])): ?>
<div class="section-divider reveal"><div class="line"></div><div class="diamond"></div><div class="line"></div></div>
<?php endif; ?>

<?php endforeach; ?>

<div class="section-divider reveal"><div class="line"></div><div class="diamond"></div><div class="line"></div></div>

<!-- ═══════════════════════════════════════════════════════════════════
     FRONTIER SCIENCE — THE RESEARCH UNDERNEATH
     ═══════════════════════════════════════════════════════════════════ -->
<section class="frontier-section reveal">
  <div class="frontier-intro">
    <div class="mono" style="font-size:0.65rem; letter-spacing:0.2em; text-transform:uppercase; color:var(--amber); margin-bottom:0.8rem;">From the Lab Bench</div>
    <h2>Frontier Science Feeding the Machine</h2>
    <p>The research signals underneath the enterprise news. These breakthroughs — in compression, compute, cognition, and drug discovery — are the tectonic plates on which the business stories above are riding.</p>
  </div>

  <div class="frontier-grid">
<?php foreach ($edition['frontier']['cards'] as $fi => $fcard): ?>
<?php $delayClass = 'reveal-delay-' . (($fi % 3) + 1); ?>
    <div class="frontier-card reveal <?php echo $delayClass; ?>">
      <div class="card-category"><?php echo htmlspecialchars($fcard['category']); ?></div>
      <div class="card-title"><a href="<?php echo htmlspecialchars($fcard['url']); ?>" target="_blank"><?php echo htmlspecialchars($fcard['title']); ?></a></div>
      <div class="card-summary"><?php echo htmlspecialchars($fcard['summary']); ?></div>
    </div>
<?php endforeach; ?>
  </div>
</section>


<!-- ═══════════════════════════════════════════════════════════════════
     SCROLL REVEAL
     ═══════════════════════════════════════════════════════════════════ -->
<script>
document.addEventListener('DOMContentLoaded', () => {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
      }
    });
  }, { threshold: 0.08, rootMargin: '0px 0px -40px 0px' });

  document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
});
</script>

</body>
</html>