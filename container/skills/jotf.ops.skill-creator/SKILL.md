---
name: jotf.ops.skill-creator
description: >
  Create new JOTF skills that comply with the Skill Manifest standard, include
  domain-appropriate guardrails, wire up progress reporting, and pass pre-flight
  validation. Use when building any new skill, scaffold skill, or creating a
  SKILL.md. Prevents silent fallbacks, missing guardrails, wrong paths, and
  unwired infrastructure.
domain: ops
version: 0.1.0

allowed-tools: Read Write Edit Glob Grep Bash

inputs:
  - name: skill_name
    type: text
    description: "Fully qualified jotf.{domain}.{function} name"
    required: false
  - name: purpose
    type: text
    description: "What the skill does — extract from user's request context"
    required: false

outputs:
  - name: skill_md
    type: file:md
    description: "Complete SKILL.md at /home/node/.claude/skills/{name}/SKILL.md"
---

# Skill Creator

Create new skills that are compliant, guardrailed, and verified. Follow all five phases in order. Do NOT tell the user the skill is ready until Phase 4 passes.

## Phase 1 — Intake

Extract these from the user's request (don't interview — infer, then confirm):

1. **Name**: `jotf.{domain}.{function}` — lowercase, dots + hyphens only
2. **Domain**: one of `signal`, `taster`, `marketing`, `publish`, `intel`, `ops`
3. **Purpose**: one sentence
4. **External dependencies**: Docker API? SMTP? FTP? Third-party URLs?
5. **Step count**: how many discrete stages? (determines pipeline vs utility)
6. **Upstream/downstream**: does it chain from or feed into other `jotf.*` skills?

If anything is ambiguous, ask one focused question. Do not run a long Q&A.

## Phase 2 — Scaffold

Read at least one existing skill from the **same domain** before writing:
```bash
ls /home/node/.claude/skills/jotf.{domain}.*/SKILL.md
```
Read one to match its patterns. Then generate the new SKILL.md:

### Required YAML frontmatter

```yaml
---
name: jotf.{domain}.{function}
description: >
  {What it does. When to use it. Keyword-rich for auto-invocation.
  Include trigger phrases: "Triggers on: ..."}
domain: {domain}
version: 0.1.0

allowed-tools: {space-separated tool list}
context: {inline or fork — use fork for heavy/isolated work}

inputs:
  - name: {snake_case}
    type: {file:json | file:html | text | url | email | json}
    description: {what this input contains}
    required: {true or false}

outputs:
  - name: {snake_case}
    type: {type}
    description: {what this output contains, including file path pattern}

depends-on:
  - {jotf.* skills that must exist}
---
```

### Required body sections

1. **Process** — numbered steps, each with clear input/output
2. **Rules** — domain guardrails (see Phase 3) + skill-specific constraints
3. **Error Handling** — one block per external dependency: what to check, what to do on failure

## Phase 3 — Wire

Inject these based on the skill's characteristics. These are NOT optional.

### Domain guardrails (embed in the Rules section)

| Domain | Inject These Rules |
|--------|-------------------|
| signal | Signal source is Docker API ONLY: `curl -s "http://host.docker.internal:3000/api/daily-oracle?date=START&date_end=END"`. NEVER use WebSearch as substitute. If API unreachable, STOP and report failure. |
| taster | Read profiles at runtime from `/workspace/group/taster/profiles/`. Never copy profile data into prompts or skill instructions as static snapshots. |
| marketing | No internal JOTF strategy in public-facing output. |
| publish | Verify credentials/connectivity before attempting delivery. Test the endpoint first. |
| intel | Large results may exceed context. Note chunking strategy if applicable. |
| ops | Read-only operations unless explicitly writing to `/workspace/group/`. |

### Universal guardrails (ALL skills get these)

- **Filesystem**: Always write to `/workspace/group/` or `/workspace/ipc/`. NEVER write to `/workspace/project/` (read-only mount).
- **Verify before reporting success**: Every skill must include a verification step for each external dependency. "It should work" is not verification — test it.

### Pipeline wiring (skills with >2 steps)

Add IPC progress reporting at each step. Insert this pattern into the Process section:

```bash
echo '{"message":"🔵 {SkillName} {N}/{Total} — {step_description}"}' > /workspace/ipc/progress/step-{N}.json
```

Use `🔵` for in-progress, `✅` for pipeline complete (with summary stats), `❌` for failure (with error detail). The host relays each message to the ops channel.

At the end of the Process section, add:
```bash
echo '{"message":"✅ {SkillName} complete — {summary}"}' > /workspace/ipc/progress/done.json
```

On any failure:
```bash
echo '{"message":"❌ {SkillName} failed at step {N}/{Total} — {error}"}' > /workspace/ipc/progress/error.json
```

## Phase 4 — Pre-flight Checklist

Run ALL checks. The skill is NOT done until every check passes.

```
CHECK 1 — File exists
  ls /home/node/.claude/skills/{name}/SKILL.md

CHECK 2 — Frontmatter fields
  Read the file. Confirm YAML has: name, description, domain, version.
  For pipeline skills: also inputs and outputs.

CHECK 3 — Name format
  Name matches jotf.{domain}.{function} pattern.

CHECK 4 — Valid domain
  Domain is one of: signal, taster, marketing, publish, intel, ops.

CHECK 5 — No read-only writes
  Grep the SKILL.md for /workspace/project/ used as a write target.
  If found → FAIL. Fix to use /workspace/group/ or /workspace/ipc/.

CHECK 6 — Signal domain WebSearch prohibition
  If domain is signal: grep for "WebSearch".
  If found without "NEVER" or "DO NOT" nearby → FAIL.

CHECK 7 — Progress reporting (pipeline skills)
  If the skill has >2 steps: grep for "ipc/progress".
  If missing → FAIL. Add progress reporting per Phase 3.

CHECK 8 — External dependency coverage
  For each external dependency (Docker API, SMTP, FTP, URLs):
  the skill must include both a verification step AND an explicit
  failure/stop instruction. If either is missing → FAIL.

CHECK 9 — Read-back
  Read the entire SKILL.md back. Confirm it parses, reads coherently,
  and the Process steps are numbered and complete.
```

If any check fails: fix the issue, then re-run ALL checks from the top.

## Phase 5 — Register

1. Emit ops notification:
```bash
echo '{"message":"✅ New skill created: jotf.{domain}.{function}"}' > /workspace/ipc/progress/skill-created.json
```

2. Tell the user:
   - Skill location: `/home/node/.claude/skills/{name}/SKILL.md`
   - The skill is persistent — it survives container restarts automatically
   - Do NOT ask about permanence, staging, or container rebuilds. Just confirm it's done.

3. If the skill chains with other `jotf.*` skills, verify the upstream/downstream skills exist:
```bash
ls /home/node/.claude/skills/{upstream-skill}/SKILL.md
```

## Reference: Existing Skills by Domain

| Domain | Examples | Pattern |
|--------|----------|---------|
| signal | jotf.signal.fetch, .filter, .curate | Pipeline chain, Docker API source, schema outputs |
| taster | jotf.taster.render, .deliver, .persona | Profile-driven, dual output (web+email), fork context |
| publish | jotf.publish.ftp, .smtp | Credential-gated utilities, verify before send |
| intel | jotf.intel.browse, .pdf, .transcribe | External tool wrappers, Bash-restricted |
| marketing | jotf.marketing.coach, .slack-format | Voice/style enforcement |
| ops | jotf.ops.status, .capabilities, .github | Read-only health checks, system info |
