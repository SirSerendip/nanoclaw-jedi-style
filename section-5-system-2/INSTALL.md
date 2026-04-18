# NanoClaw Capability Package

## Prerequisites
- NanoClaw installed and running
- Claude Code available (`which claude`)
- Run from the NanoClaw project root

## Installation

1. Extract this archive:
   ```bash
   tar -xzf nanoclaw-export-*.tar.gz
   ```

2. Copy the install skill into your NanoClaw project:
   ```bash
   cp -r path/to/extracted/.claude/skills/install-package/ /path/to/nanoclaw/.claude/skills/
   ```

3. From your Claude Code session in the NanoClaw project:
   ```
   /install-package
   ```

Claude Code will guide you through the rest.

## Alternative: one-liner

From your NanoClaw project root:
```bash
bash /path/to/extracted/install-bootstrap.sh
```
Then in Claude Code:
```
/install-package /path/to/extracted
```

## Contents

This package contains NanoClaw capabilities exported by another operator. The exact contents are listed in `package-manifest.json`.

## Troubleshooting

- The installation can be cancelled at any point — all changes are rolled back
- If a patch fails to apply, it usually means a version mismatch — the installer will show you the patch so you can apply it manually
- After installation, run `npm run build` and restart the NanoClaw service
