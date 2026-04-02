---
name: smtp-send
description: Send emails via SMTP. Use when directing output to colleagues not on Slack — teasers, reports, artifact links. Only available in the main channel.
allowed-tools: Bash(smtp-send:*)
---

# SMTP Send

Send emails to colleagues via SMTP. **Main channel only** — credentials are not available in other groups.

Sender is always `hello@jedionthefly.com`. You compose the subject and HTML body based on context.

## Quick start

```bash
smtp-send check                                          # Verify SMTP credentials
smtp-send send --to colleague@example.com \
  --subject "Check this out" \
  --body "<p>Here's the latest.</p>"
```

## Commands

### send — Send an email

```bash
smtp-send send --to <email> --subject <subject> --body <body>
```

- `--to` — Recipient email address (required)
- `--subject` — Email subject line (required)
- `--body` — Email body, supports HTML (required)

The body is sent as both plain text (HTML tags stripped) and HTML. Use HTML for links, headings, and emphasis.

### check — Verify SMTP credentials

```bash
smtp-send check
```

Confirms that SMTP_HOST, SMTP_USER, and SMTP_PASS are available.

## Use Cases

### Newsletter teaser (Hamid's Smoke Break)

Send a teaser with a link back to the Slack channel where the full newsletter lives:

```bash
smtp-send send \
  --to hamid@example.com \
  --subject "Hamid's Smoke Break — Apr 1" \
  --body "<h2>Today's Top Stories</h2><p>3 items curated for your morning read.</p><p><a href='https://slack-channel-link'>Read the full edition in Slack</a></p>"
```

### Artifact sharing (Wardley Maps, reports)

Send a teaser with a permalink to the artifact:

```bash
smtp-send send \
  --to colleague@example.com \
  --subject "New Wardley Map: Platform Strategy" \
  --body "<p>Just published a new map analyzing our platform positioning.</p><p><a href='https://draw.jedionthefly.com/board/xyz'>View the Wardley Map</a></p>"
```

## Error handling

- **"SMTP credentials not available"** — This tool only works in the main channel. SMTP credentials are not passed to other groups.
- **"Failed to send email"** — Check credentials with `smtp-send check`. Verify the SMTP host and port are correct.
