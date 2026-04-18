---
name: export
description: Export NanoClaw capabilities as a shareable package. Creates a self-contained .tar.gz that another operator can install with /install-package. Triggers on "export", "export capabilities", "create package", "share capabilities".
---

SECURITY INVARIANT: This skill never reads, displays, or packages env var VALUES. It only reads KEY NAMES to build the recipient's configuration interview. Values are entered fresh by the recipient during /install-package.

# Export Skill

This skill creates a shareable capability package from the current NanoClaw installation. It walks the operator through a 9-step interactive process, collecting selections, reviewing sensitive content, and assembling a self-contained archive.

All user-facing text must match the operator's language (respond in the same language the user writes in).

## Step 1 — Introduction

Display an overview of the export process in French:

- Explain what the export does: packages selected capabilities, skills, patches, and sanitized configuration into a `.tar.gz` archive that another operator can install using `/install-package`.
- Explain what is excluded: `.env` files, `messages.db`, personal data (phone numbers, JIDs), credentials, and group-specific conversation history.
- Estimated time: 5-10 minutes depending on number of capabilities.

Example opening:

> **NanoClaw Capability Export**
>
> This process will create a portable package containing your selected capabilities. The package can be installed by another operator using `/install-package`.
>
> **Automatically excluded:** `.env` files, `messages.db` database, personal data (phone numbers, JIDs), credentials, conversation history.
>
> **Estimated time:** 5-10 minutes.

## Step 2 — Detect Capabilities

Run the capability registry scanner:

```bash
bash scripts/export/registry.sh
```

Parse the JSON output. Display a numbered list of detected capabilities with:
- Label (human-readable name)
- Version (if available)
- Dependencies (other capabilities it requires)

Example display:

> **Detected capabilities:**
>
> 1. observability (v1.2.0) — deps: none
> 2. backup (v1.0.3) — deps: observability
> 3. emergency (v0.9.1) — deps: observability, backup

## Step 3 — Capability Selection

Use `AskUserQuestion` to ask which capabilities to export. Accept numbered list (e.g., "1, 3") or "tout" for all.

After selection:
- Resolve dependencies automatically. If a selected capability depends on an unselected one, add the dependency and inform the operator.
- Display the final ordered selection list.
- Use `AskUserQuestion` to confirm the selection before proceeding.

Example:

> Capability "emergency" requires "observability" and "backup". Added automatically.
>
> **Final selection (install order):**
> 1. observability
> 2. backup
> 3. emergency
>
> Confirm this selection?

## Step 3.5 — ENV VAR AUDIT

Read `.env` key names only (never values):

```bash
grep -v '^#' .env | grep -v '^$' | cut -d'=' -f1 | sort
```

Define the following as INFRASTRUCTURE_VARS (never exported, never included in packages):
- ANTHROPIC_API_KEY
- CLAUDE_CODE_OAUTH_TOKEN
- ASSISTANT_NAME
- CREDENTIAL_PROXY_PORT
- CONTAINER_IMAGE
- CONTAINER_TIMEOUT
- IDLE_TIMEOUT
- MAX_CONCURRENT_CONTAINERS
- TZ

For each env key that is NOT in INFRASTRUCTURE_VARS and NOT already declared in a selected capability's `env_keys` array, use `AskUserQuestion` to ask the operator to:
1. Associate it with one of the selected capabilities
2. Create a new capability entry for it
3. Ignore it (will not be included in the package)

For capabilities that have `needs_env_audit: true` in their registry entry: use `AskUserQuestion` to ask the operator what env vars they need, and record those in the capability's `env_keys`.

Display a summary of all env var dispositions:

> **Environment variable audit:**
>
> **Associated with a capability:**
> - VAR_NAME -> capability_name
>
> **Ignored:**
> - VAR_NAME
>
> **Infrastructure (auto-excluded):**
> - ANTHROPIC_API_KEY, CLAUDE_CODE_OAUTH_TOKEN, ...

Use `AskUserQuestion` to confirm the env var audit before proceeding.

## Step 4 — Global CLAUDE.MD Interview

Read the file `groups/global/CLAUDE.md`.

Run the section analyzer:

```bash
bash scripts/export/extract-claude-md.sh groups/global/CLAUDE.md
```

For each section in the output, apply the following logic:

- **Sentinel-marked sections** (sections between `<!-- EXPORT-START -->` and `<!-- EXPORT-END -->` markers): Show a preview of the content. Use `AskUserQuestion` to ask whether to include it. Default: yes.

- **Sections flagged as personal** (containing phone numbers, JIDs, personal names, addresses): Show the content and the reasons it was flagged. Use `AskUserQuestion` to ask whether to include it. Default: no.

- **Sections flagged as exportable** (general configuration, capability docs, non-personal content): Show the content. Use `AskUserQuestion` to ask whether to exclude it. Default: no (i.e., include by default).

After all sections are reviewed, run sanitization on the approved sections to strip any remaining personal data. Show the sanitized result and use `AskUserQuestion` for final confirmation.

## Step 5 — Generate Patches

For each selected capability that has associated `src/` files, generate patches:

```bash
bash scripts/export/generate-patches.sh <capability-name>
```

Display results for each capability:
- Patch file size
- Any warnings (e.g., binary files skipped, large patches)

If any warnings are present, use `AskUserQuestion` to confirm continuation.

## Step 6 — Operator Notes

Use `AskUserQuestion` to ask for an optional free-text note to include in the package:

> Would you like to add a note for the package recipient? (leave empty to skip)

Store the response (even if empty) for inclusion in the manifest.

## Step 7 — Build Manifest

Assemble `package-manifest.json` from all collected data:

```json
{
  "format_version": "1.0",
  "created_at": "<ISO 8601 timestamp>",
  "source_version": "<nanoclaw version from package.json>",
  "capabilities": [
    {
      "name": "<capability>",
      "version": "<version>",
      "dependencies": ["<dep1>", "<dep2>"]
    }
  ],
  "claude_md_sections": ["<section1>", "<section2>"],
  "operator_notes": "<free text or null>",
  "checksums": {}
}
```

Write the manifest to a temporary file for the assembly step.

## Step 8 — Final Review

Display a summary of what will be packaged:

- Number and names of capabilities
- Number of patch files
- Number of CLAUDE.md sections included
- Operator notes (if any)
- Estimated archive size

Use `AskUserQuestion` with the prompt:

> **Resume du package :**
> - Capacites : 3 (observability, backup, emergency)
> - Patches : 7 fichiers
> - Sections CLAUDE.md : 4
> - Notes operateur : oui
> - Taille estimee : ~45 KB
>
> Creer le package ?

## Step 9 — Assembly

Run the assembly script with the manifest:

```bash
bash scripts/export/assemble.sh <manifest-file-path>
```

Display the results:
- Archive file path
- Archive size
- SHA256 checksum

Show instructions for the recipient in French:

> **Package cree avec succes !**
>
> Fichier : `exports/nanoclaw-package-<timestamp>.tar.gz`
> Taille : 45 KB
> SHA256 : `abc123...`
>
> **Instructions pour le destinataire :**
> 1. Copier le fichier `.tar.gz` dans le repertoire racine de NanoClaw
> 2. Executer `/install-package nanoclaw-package-<timestamp>.tar.gz`
> 3. Suivre les instructions d'installation interactives
