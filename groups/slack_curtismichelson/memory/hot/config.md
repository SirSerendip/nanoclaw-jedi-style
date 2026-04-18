## Configuration

| Key | Value | Notes |
|-----|-------|-------|
| Slack bold | `*text*` single asterisk | `**` renders as literal characters |
| Slack URLs | Never bold | Breaks link rendering |
| Slack italics | `_text_` | Standard mrkdwn |
| Slack code | Backticks `` `code` `` | Triple for blocks |
| File upload primary | catbox.moe `reqtype=fileupload` | Permanent hosting |
| File upload fallback | litterbox.catbox.moe | 72h temporary |
| Website local path | `/workspace/extra/CurtisMichelson.com/` | Mounted read-write |
| Site URL | `https://curtismichelson.com/` | Production URL |
| FTP target | `ftp.curtismichelson.com` | Via `ftp-upload` skill |
| GitHub repo | `SirSerendip/curtismichelson.com` | Backup repo |
