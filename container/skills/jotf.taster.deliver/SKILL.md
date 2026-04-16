---
name: jotf.taster.deliver
description: >
  Deliver a rendered Taster edition to the recipient via email, FTP, or Slack.
  Handles inline HTML email delivery, web publishing, and multi-channel routing.
  Use when a rendered edition (web.html + email.html) is ready for delivery.
  Triggers on: "deliver taster", "send taster", "publish edition", "email taster".
domain: taster
version: 0.1.0

allowed-tools: Read Bash(smtp-send:*) Bash(ftp-upload:*) Bash(curl:*) mcp__nanoclaw__send_message

inputs:
  - name: edition_dir
    type: text
    description: "Path to the edition directory containing web.html and email.html (e.g., /workspace/group/taster/editions/robyn-bolton/2026-04-16/)"
  - name: profile_json
    type: file:json
    description: Thinker persona profile with delivery config

outputs:
  - name: delivery_receipt
    type: json
    description: "Delivery status for each channel: {channel, status, timestamp, details}"

depends-on:
  - jotf.taster.render
  - jotf.taster.persona

env_keys:
  - SMTP_HOST
  - SMTP_USER
  - SMTP_PASS
---

# Taster Deliver — Multi-Channel Routing

Deliver a rendered Taster edition to the recipient through their configured channels.

## Quick Start

```
Deliver the robyn-bolton edition from 2026-04-16
```

## Delivery Channels

### 1. Email — Inline HTML (`email-inline`)

This is the primary delivery method for most tasters. The email body IS the newsletter — no links, no attachments, the full rendered edition appears inline in the recipient's email client.

#### The smtp-send Wrapper Problem

The `smtp-send` script wraps `--body` content in its own HTML chrome (adds header, footer, "Sent by Jedi Claw" branding). For Taster editions, this creates double-wrapping since `email.html` is already a complete HTML document.

#### Solution: Direct SMTP via curl

For inline HTML email delivery, bypass `smtp-send` and construct the SMTP payload directly:

```bash
# Read the email HTML file
EMAIL_BODY=$(cat /workspace/group/taster/editions/{slug}/{date}/email.html)

# Build the MIME message
cat > /tmp/taster-email.eml << 'MIME_EOF'
From: La Force <hello@jedionthefly.com>
To: {recipient_email}
Subject: {subject_line}
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8

{EMAIL_BODY}
MIME_EOF

# Send via curl SMTP
curl --ssl-reqd \
  --url "smtps://${SMTP_HOST}:465" \
  --user "${SMTP_USER}:${SMTP_PASS}" \
  --mail-from "hello@jedionthefly.com" \
  --mail-rcpt "{recipient_email}" \
  --upload-file /tmp/taster-email.eml \
  --silent --show-error
```

**Important:** Use the persona's `delivery.subject_template` to build the subject line. Replace `{edition_title}` with the curated edition title and `{date}` with the formatted date.

#### Pre-Flight Checks

Before sending email:
1. Verify SMTP credentials: `smtp-send check`
2. Confirm `email.html` exists and is non-empty
3. Confirm recipient email is valid (basic format check)
4. Log the delivery attempt

### 2. Email — Link Only (`email-link`)

Send a teaser email with a link to the web version. Use `smtp-send` normally for this:

```bash
smtp-send send \
  --to "{recipient_email}" \
  --subject "{subject_line}" \
  --body "<h2>{mile_zero.name}</h2><p>{edition_title}</p><p><a href='{web_url}'>Read the full edition</a></p>"
```

### 3. FTP — Web Publishing (`web`)

Upload `web.html` to the public web server:

```bash
ftp-upload /workspace/group/taster/editions/{slug}/{date}/web.html taster/{slug}/{date}.html
```

This publishes to `https://draw.jedionthefly.com/taster/{slug}/{date}.html` (or wherever the FTP root maps to).

### 4. Slack — Channel Message (`slack`)

Post a teaser with a link to the web version:

```
Use mcp__nanoclaw__send_message to post:
"🚀 New {mile_zero.name} edition: {edition_title}
{signal_count} signals curated through {thinker_count} thinker lenses.
Read it: {web_url}"
```

### 5. Multi-Channel (`multi`)

When the persona's `delivery.channels` lists multiple channels, deliver to each in sequence:
1. FTP upload first (so web URL is available for teasers)
2. Email delivery
3. Slack notification

## Delivery Receipt

After all deliveries complete, write a receipt:

```json
{
  "persona": "robyn-bolton",
  "edition_date": "2026-04-16",
  "edition_title": "The First Mile Is Always Politics",
  "deliveries": [
    {
      "channel": "email-inline",
      "recipient": "robyn@example.com",
      "status": "sent",
      "timestamp": "2026-04-16T02:05:00-04:00",
      "subject": "MileZero · The First Mile Is Always Politics · Apr 16, 2026"
    },
    {
      "channel": "web",
      "url": "https://draw.jedionthefly.com/taster/robyn-bolton/2026-04-16.html",
      "status": "uploaded",
      "timestamp": "2026-04-16T02:04:30-04:00"
    }
  ]
}
```

Save to `/workspace/group/taster/editions/{slug}/{date}/delivery-receipt.json`.

## Cleanup

After successful delivery:
- Remove `/tmp/taster-email.eml` if created
- Log a summary to stdout: channels delivered, recipients, status

## Error Handling

- **SMTP credentials missing** — Run `smtp-send check`. If credentials unavailable, skip email delivery and warn.
- **curl SMTP failure** — Capture stderr. Common issues: wrong port, expired credentials, recipient rejected.
- **FTP upload failure** — Check if `ftp-upload` skill is available. Retry once on timeout.
- **Empty email.html** — Do not send. Warn and abort email delivery.
- **Multi-channel partial failure** — Deliver to all channels independently. Report per-channel status in the receipt. Don't let one channel's failure block others.

## Changelog

- `0.1.0` — Initial release. Direct curl SMTP for inline email, multi-channel routing, delivery receipts.
