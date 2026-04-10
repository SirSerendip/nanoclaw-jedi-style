---
name: ftp-upload
description: Upload files via FTP. Use when publishing HTML pages, images, or assets to the web. Available in any channel with FTP credentials configured.
allowed-tools: Bash(ftp-upload:*)
---

# FTP Upload

Upload files via FTP. Available in any channel where FTP credentials are configured via `credentialKeys`.

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

## Error handling

- **"FTP credentials not available"** — FTP credentials are not configured for this channel. The admin must add `credentialKeys` to the group's `containerConfig`.
- **"File not found"** — Check the file path. Use an absolute path or path relative to the working directory.
- **"Upload failed"** — Check network connectivity and verify credentials with `ftp-upload check`.
