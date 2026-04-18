# JOTF Skill Manifest Standard

> Version 0.1 · 2026-04-16 · Authors: Hamid Ennachat, Curtis Michelson, The Force

## Why This Exists

We're building a library of composable skill "bricks" — each one independently callable, chainable into pipelines, and transparent about what it does, what it needs, and what it produces. This standard ensures:

- **Transparency** — teammates (human and AI) know every skill's real capabilities
- **Interoperability** — skills declare typed inputs/outputs so they can compose into pipelines
- **Resilience** — dependency and version tracking prevents silent breakage when bricks change

## Anatomy of a JOTF Skill

Every skill lives in a `SKILL.md` file. The YAML frontmatter at the top **is** the manifest. The markdown body below contains instructions, usage docs, and examples.

```yaml
---
# ── Identity (required) ──────────────────────────────────
name: jotf.taster.render
description: >
  Build web + email HTML from curated signals and a thinker profile.
  Use when a curated signals JSON and a profile are ready for rendering.
domain: taster
version: 0.1.0

# ── Runtime (optional) ───────────────────────────────────
allowed-tools: Bash(jotf-taster-render:*) Read Write Edit Glob
context: fork
effort: medium
model: sonnet

# ── Interface (required for pipeline skills) ─────────────
inputs:
  - name: signals_json
    type: file:json
    description: Curated sections with pre-rendered HTML signal fragments
    schema: schemas/signals.schema.json
  - name: profile_json
    type: file:json
    description: Thinker profile with palette, typography, delivery prefs
    schema: schemas/thinker-profile.schema.json
outputs:
  - name: web_html
    type: file:html
    description: Full web version with CSS variables, dark mode, animations
  - name: email_html
    type: file:html
    description: Email-safe version with inline styles, table layout, PNG logo

# ── Dependencies (optional) ──────────────────────────────
depends-on:
  - jotf.taster.persona   # must exist to produce profile_json
  - jotf.signal.curate     # must exist to produce signals_json

# ── Credential requirements (optional) ───────────────────
env_keys:
  - SMTP_HOST
  - SMTP_USER
---
```

## Field Reference

### Identity Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Fully qualified `jotf.{domain}.{function}` name. Lowercase, dots + hyphens only. |
| `description` | ✅ | What the skill does and when to trigger it. Claude uses this for auto-invocation. Be keyword-rich. |
| `domain` | ✅ | One of the six JOTF domains (see Taxonomy below). |
| `version` | ✅ | Semver (`major.minor.patch`). Bump minor for new capabilities, major for breaking interface changes. |

### Runtime Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `allowed-tools` | No | all | Space-separated tool permissions. Use `Bash(script:*)` for scripts. |
| `context` | No | inline | `fork` runs in a subagent. Use for heavy/isolated work. |
| `effort` | No | medium | Model effort: `low`, `medium`, `high`, `max`. |
| `model` | No | inherited | Override model: `haiku`, `sonnet`, `opus`. |
| `env_keys` | No | `[]` | Environment variables / secrets the skill requires. |

### Interface Fields

| Field | Required | Description |
|-------|----------|-------------|
| `inputs` | Pipeline skills | Array of named inputs with type and description. |
| `inputs[].name` | ✅ | Identifier (snake_case). Used in pipeline wiring. |
| `inputs[].type` | ✅ | Type hint (see Type System below). |
| `inputs[].description` | ✅ | What this input contains and how it's used. |
| `inputs[].schema` | No | Path to JSON Schema for validation. Relative to skill directory. |
| `inputs[].required` | No | Default `true`. Set `false` for optional inputs. |
| `outputs` | Pipeline skills | Array of named outputs with type and description. |
| `outputs[].name` | ✅ | Identifier (snake_case). |
| `outputs[].type` | ✅ | Type hint. |
| `outputs[].description` | ✅ | What this output contains. |

### Dependency Fields

| Field | Required | Description |
|-------|----------|-------------|
| `depends-on` | No | List of `jotf.*` skill names this skill requires to exist. Not "runs after" — just "must be installed." |

## Type System

Types are hints, not enforcement. They help humans and agents understand what flows between skills.

| Type | Description | Example |
|------|-------------|---------|
| `file:json` | JSON file on disk | `signals.json`, `profile.json` |
| `file:html` | HTML file on disk | `taster-email.html` |
| `file:pdf` | PDF file | `report.pdf` |
| `file:md` | Markdown file | `analysis.md` |
| `file:*` | Any file | `attachment.xlsx` |
| `text` | Plain string (inline, not a file) | A subject line, a URL |
| `url` | A URL string | `https://example.com/page` |
| `email` | Email address | `anna@example.com` |
| `json` | Inline JSON object (not a file) | `{"status": "sent"}` |

## Taxonomy: The Six Domains

```
jotf.signal.*     Upstream intelligence — fetch, filter, curate raw signals
jotf.taster.*     Collision pieces — render, deliver, manage thinker profiles
jotf.marketing.*  Brand & growth — copy coaching, style checks, campaigns
jotf.publish.*    Distribution — FTP, email, Slack delivery
jotf.intel.*      Knowledge work — PDFs, transcription, browsing, library
jotf.ops.*        System health — status, capabilities, GitHub, project mgmt
```

### Current Skill Registry

| Current Name | New Name | Domain | Type | Status |
|-------------|----------|--------|------|--------|
| `mind-trick` | `jotf.marketing.mind-trick` | marketing | container | rename |
| — | `jotf.marketing.style-check` | marketing | container | **new** |
| `ftp-upload` | `jotf.publish.ftp` | publish | utility | rename |
| `smtp-send` | `jotf.publish.email` | publish | utility | rename |
| `slack-formatting` | `jotf.publish.slack` | publish | container | rename |
| `pdf-reader` | `jotf.intel.pdf` | intel | utility | rename |
| `transcribe-audio` | `jotf.intel.transcribe` | intel | container | rename |
| `agent-browser` | `jotf.intel.browse` | intel | container | rename |
| `jotf-library` | `jotf.intel.library` | intel | container | rename |
| `meetos` | `jotf.intel.meetos` | intel | container | rename |
| `status` | `jotf.ops.status` | ops | container | rename |
| `capabilities` | `jotf.ops.capabilities` | ops | container | rename |
| `github-ops` | `jotf.ops.github` | ops | container | rename |
| `multi-project` | `jotf.ops.projects` | ops | utility | rename |
| — | `jotf.signal.fetch` | signal | utility | **new** |
| — | `jotf.signal.filter` | signal | utility | **new** |
| — | `jotf.signal.curate` | signal | utility | **new** |
| — | `jotf.taster.render` | taster | utility | **new** |
| — | `jotf.taster.deliver` | taster | utility | **new** |
| — | `jotf.taster.persona` | taster | utility | **new** |

### Pipeline Example: Signal → Taster

```
jotf.signal.fetch ──→ jotf.signal.filter ──→ jotf.signal.curate ──→ jotf.taster.render ──→ jotf.taster.deliver
     │                      │                      │                      │                      │
     ▼                      ▼                      ▼                      ▼                      ▼
 Raw Signals JSON     Candidates JSON       Curated Sections JSON    HTML (web + email)     Delivered artifact
                           │                                               │
                           ▼                                               ▼
                    jotf.taster.persona ────────────────────────────► Profile JSON
```

Each arrow represents an output→input contract. If `jotf.signal.curate` changes its output schema, `jotf.taster.render` (which `depends-on` it) knows to check compatibility.

## Migration Guide

### Renaming an existing skill

1. Rename the directory: `mv ~/.claude/skills/old-name ~/.claude/skills/jotf.domain.function`
2. Update the frontmatter `name:` field
3. Add `domain:` and `version: 0.1.0`
4. Add `description:` if missing or too terse
5. For pipeline skills, add `inputs:` and `outputs:`
6. Test invocation: run the skill by name and verify auto-trigger still works

### Writing a new pipeline skill

1. Start with the frontmatter — define interface before writing instructions
2. Declare all inputs and outputs with types
3. Reference JSON Schemas in `schemas/` if the data shape is non-trivial
4. Add `depends-on` for skills that must exist (not "runs before" — just "must be installed")
5. Write the instruction body: how to invoke, what to expect, error handling
6. Version at `0.1.0` — bump when the interface changes

## Conventions

### Naming

- **Skill name**: `jotf.{domain}.{function}` — all lowercase, dots separate namespace levels, hyphens within function names
- **Directory name**: same as skill name (dots in directory names are fine)
- **Script names**: match the function part — `jotf.publish.email` ships a script called `smtp-send` (legacy) or `email-send`

### Versioning

- `0.x.y` — pre-stable. Interface may change without notice.
- `1.0.0` — stable interface. Breaking changes require major bump.
- Bump **patch** for bug fixes and internal changes.
- Bump **minor** for new optional inputs/outputs.
- Bump **major** for breaking interface changes (renamed/removed inputs/outputs, changed types).

### Documentation

The SKILL.md body (below the frontmatter) should contain:

1. **Quick start** — 3-5 line example showing the most common invocation
2. **Commands / Workflow** — detailed usage
3. **Examples** — real invocations with expected output
4. **Error handling** — common failures and how to recover
5. **Changelog** — brief version history (optional, can be a separate file)

## Schema Files (Optional)

For pipeline skills with complex JSON interfaces, store JSON Schema files alongside the SKILL.md:

```
~/.claude/skills/jotf.taster.render/
  SKILL.md
  schemas/
    signals.schema.json
    thinker-profile.schema.json
  templates/
    web.html
    email.html
```

Schemas serve two purposes:
1. **Documentation** — precise definition of what the input/output looks like
2. **Validation** — scripts can validate data before processing

## What This Standard Does NOT Cover

- **Orchestration** — how skills are chained at runtime (that's the caller's job, not the manifest's)
- **Authentication** — skill-to-skill trust (all skills run in the same agent context today)
- **Marketplace registration** — this is a JOTF-internal standard; NanoClaw marketplace uses the base Claude Code format

---

*This is a living document. Update it as the taxonomy and pipeline evolve.*
