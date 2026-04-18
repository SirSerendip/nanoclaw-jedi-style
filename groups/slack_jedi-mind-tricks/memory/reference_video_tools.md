---
name: Short-Form Video Tools Research
description: Muted-first caption-forward video tools for LinkedIn talking head clips — from quick-start apps to programmatic pipelines
type: reference
---

## Format
Muted-first, caption-forward short videos — big animated text captions, plays silent by default, audio on click-in. Dominant format across LinkedIn, TikTok, Reels, Shorts.

## Quick-Start Tools (No Code)
- **Opus Clip** (opus.pro) — $19/mo. Purpose-built for talking head. AI finds viral moments, auto-reframes 9:16, animated word-by-word captions. Best for clipping longer recordings.
- **Submagic** (submagic.co) — From $9/mo. Best caption styling: trendy animations, font/color control, sound effects on keywords. Finishing tool for existing clips. *Built on Remotion's stack* — validates Remotion as battle-tested and makes Phase 1→2 migration seamless.
- **Captions** (captions.ai) — One-tap AI editing, auto-cuts, B-roll overlays, 91+ languages.
- **CapCut** (capcut.com) — Free, from ByteDance. Native TikTok integration, auto-captions, huge template library.
- **VEED.io** — 99.9% accuracy, dynamic pop/glide caption effects. Browser-based.
- **Kapwing** — 100+ caption presets, team Brand Kit support.

## Programmatic / Automatable (Phase 2)
- **Remotion** (remotion.dev) — Open-source React framework. Has `createTikTokStyleCaptions()` function and TikTok template. Captions are React components — fully customizable. Could pipe collision narratives directly into branded video templates. Works with Claude Code.
- **auto-subtitle / faster-auto-subtitle** — Open-source Python: Whisper + FFmpeg. Simple CLI.
- **Swiftia** — API-first. Feeds long-form, outputs 20-30 clips with animated captions and branding.

## Recommended Phasing
- Phase 1 (now): Opus Clip or Submagic for quick record-and-post
- Phase 2 (scale): Remotion for templated, pipeline-integrated video generation
