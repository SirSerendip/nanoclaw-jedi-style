---
name: ftp-upload
description: Upload files to jedionthefly.com via FTP. Use when publishing HTML pages, images, or assets to the web. Only available in the main channel.
allowed-tools: Bash(ftp-upload:*)
---

# FTP Upload

Upload files to jedionthefly.com via FTP. **Main channel only** — credentials are not available in other groups.

## Quick start

```bash
ftp-upload check                            # Verify FTP credentials are set
ftp-upload upload page.html /collisions     # Upload to /collisions directory
ftp-upload upload style.css /collisions/css # Upload to subdirectory
```

## Commands

### upload — Upload a file to the FTP server

```bash
ftp-upload upload <local-file> [remote-dir]
```

- `local-file` — Path to the file to upload (must exist)
- `remote-dir` — Remote directory path (default: `/`). Directories are created automatically.

### check — Verify FTP credentials

```bash
ftp-upload check
```

Confirms that FTP_HOST, FTP_USER, and FTP_PASS are available. Run this first if unsure whether FTP is configured.

## InnoLead Newsletter Publishing

The primary use case is publishing InnoLead bi-weekly newsletter pages to jedionthefly.com/collisions.

### Typical workflow

1. Generate or prepare the HTML file(s) in the workspace
2. Upload to the `/collisions` directory:

```bash
ftp-upload upload newsletter.html /collisions
ftp-upload upload styles.css /collisions/css
ftp-upload upload logo.png /collisions/images
```

The files will be accessible at `https://jedionthefly.com/collisions/<filename>`.

## Error handling

- **"FTP credentials not available"** — This tool only works in the main channel. FTP credentials are not passed to other groups.
- **"File not found"** — Check the file path. Use an absolute path or path relative to the working directory.
- **"Upload failed"** — Check network connectivity and verify credentials with `ftp-upload check`.
