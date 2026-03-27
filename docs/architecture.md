# NanoClaw Architecture

## System Overview

NanoClaw is a containerized AI agent orchestration system. A single Node.js host process manages messaging channels, queues, and state, while Claude AI agents execute in isolated Docker containers. The host and containers communicate via filesystem-based IPC and a credential proxy.

---

## Component Map

### Host-Side (Node.js Process)

| Component | File | Purpose |
|-----------|------|---------|
| Orchestrator | `src/index.ts` | Main event loop, message polling, container lifecycle |
| Container Runner | `src/container-runner.ts` | Spawns Docker containers, streams output, manages timeouts |
| Container Runtime | `src/container-runtime.ts` | Docker CLI abstraction, networking, orphan cleanup |
| Credential Proxy | `src/credential-proxy.ts` | HTTP proxy injecting real API credentials into container requests |
| Group Queue | `src/group-queue.ts` | Per-group concurrency control, message/task queueing |
| IPC Watcher | `src/ipc.ts` | Monitors filesystem IPC from containers, processes task/message operations |
| Task Scheduler | `src/task-scheduler.ts` | Polls for due tasks, spawns task containers |
| Router | `src/router.ts` | Message formatting, outbound routing to channels |
| Database | `src/db.ts` | SQLite: messages, tasks, sessions, groups, state |
| Channel Registry | `src/channels/registry.ts` | Pluggable channel factory (self-registration on import) |
| WhatsApp Channel | `src/channels/whatsapp.ts` | Baileys-based WhatsApp Web connection |
| Slack Channel | `src/channels/slack.ts` | Bolt-based Slack Socket Mode connection |
| Mount Security | `src/mount-security.ts` | Validates additional mounts against external allowlist |
| Group Folder | `src/group-folder.ts` | Path traversal prevention, folder name validation |
| Config | `src/config.ts` | Environment variable defaults |

### Container-Side (Docker)

| Component | File | Purpose |
|-----------|------|---------|
| Agent Runner | `container/agent-runner/src/index.ts` | Executes Claude SDK queries, polls IPC, streams results |
| MCP Server | `container/agent-runner/src/ipc-mcp-stdio.ts` | Exposes tools (send_message, schedule_task, etc.) to the agent |
| Dockerfile | `container/Dockerfile` | Image: node:22-slim + Chromium + Claude Code CLI |
| Entrypoint | Inline in Dockerfile | Recompiles TypeScript, reads stdin, runs agent |

---

## Directory Layout

```
NanoClaw/                          # PROJECT ROOT (host)
├── src/                           # Host application source
├── dist/                          # Compiled host JS
├── container/
│   ├── agent-runner/src/          # Agent runner source (copied per-group)
│   ├── Dockerfile
│   └── skills/                    # Skills synced into containers
├── store/
│   ├── messages.db                # SQLite database
│   └── auth/                      # WhatsApp credentials
├── groups/
│   ├── global/CLAUDE.md           # Shared system prompt (all groups)
│   ├── main/CLAUDE.md             # Main channel prompt
│   ├── whatsapp_main/CLAUDE.md    # WhatsApp group prompt
│   ├── slack_main/CLAUDE.md       # Slack group prompt
│   └── {folder}/                  # Per-group working directory
│       ├── CLAUDE.md              # Group-specific memory
│       ├── conversations/         # Archived transcripts
│       └── logs/                  # Container execution logs
├── data/
│   ├── env/env                    # .env copy for containers
│   ├── sessions/{folder}/         # Per-group Claude Code sessions
│   │   ├── .claude/               # Session data, settings, skills
│   │   └── agent-runner-src/      # Writable agent runner copy
│   └── ipc/{folder}/              # Per-group IPC namespace
│       ├── messages/              # Outgoing messages (container → host)
│       ├── tasks/                 # Task operations (container → host)
│       ├── input/                 # Incoming messages (host → container)
│       └── current_tasks.json     # Task snapshot (host → container)
├── logs/
│   ├── nanoclaw.log               # Main service log
│   └── setup.log                  # Setup log
├── .env                           # Credentials (never mounted)
└── ~/.config/nanoclaw/
    ├── mount-allowlist.json       # External mount validation
    └── sender-allowlist.json      # Per-group sender filtering
```

### Inside the Container

```
/workspace/
├── group/              # Group working directory (read-write)
├── global/             # Shared CLAUDE.md (read-only, non-main only)
├── project/            # Full project root (read-only, main only)
│   └── .env            # Shadowed with /dev/null (secrets blocked)
├── extra/              # User-configured additional mounts
└── ipc/
    ├── messages/       # Agent writes: send_message
    ├── tasks/          # Agent writes: schedule_task, pause, resume, cancel
    ├── input/          # Agent reads: follow-up messages from host
    │   └── _close      # Sentinel file: exit query loop
    ├── current_tasks.json   # Read-only task snapshot
    └── available_groups.json  # Read-only group list (main only)
/home/node/.claude/     # Claude Code sessions, settings, skills
/app/src/               # Agent runner source (recompiled on start)
```

---

## Message Lifecycle

```
                          HOST                                      CONTAINER
                          ════                                      ═════════

  WhatsApp/Slack ──→ Channel.onMessage()
                     │
                     ├─→ storeMessage() ──→ SQLite (messages table)
                     │
           ┌─────── Poll Loop (2s) ◄─────────────────────────────────────────────────┐
           │         │                                                                │
           │    getNewMessages(jids, lastTimestamp)                                    │
           │         │                                                                │
           │    Filter: trigger check, sender allowlist                                │
           │         │                                                                │
           │    Pull context: getMessagesSince(lastAgentTimestamp)                     │
           │         │                                                                │
           │    Format: XML <messages><message sender="..." time="...">               │
           │         │                                                                │
           │    queue.enqueueMessageCheck(chatJid)                                    │
           │         │                                                                │
           │         ▼                                                                │
           │    ┌─────────────────────────┐                                           │
           │    │     GROUP QUEUE         │                                           │
           │    │  max 5 concurrent       │                                           │
           │    │  tasks > messages       │                                           │
           │    │  retry w/ backoff       │                                           │
           │    └────────┬────────────────┘                                           │
           │             │                                                            │
           │    runContainerAgent()                                                   │
           │         │                                                                │
           │    docker run -i --rm                                                    │
           │      -v group:/workspace/group                                           │
           │      -v ipc:/workspace/ipc                                               │
           │      -e ANTHROPIC_BASE_URL=http://host:3001                              │
           │      nanoclaw-agent:latest                                               │
           │         │                                                                │
           │         ├─→ stdin: JSON {prompt, sessionId, groupFolder, ...}            │
           │         │                                        │                       │
           │         │                                   readStdin()                   │
           │         │                                        │                       │
           │         │                                   Launch MCP server             │
           │         │                                   (ipc-mcp-stdio.ts)            │
           │         │                                        │                       │
           │         │                                   sdk.query({                   │
           │         │                                     model: 'opus',              │
           │         │                                     prompt: MessageStream,      │
           │         │                                     systemPrompt: CLAUDE.md,    │
           │         │                                     tools: [Bash, Read, ...]    │
           │         │                                   })                            │
           │         │                                        │                       │
           │         │                                   ┌────┴────┐                   │
           │         │                                   │ Claude  │                   │
           │         │                                   │  Agent  │                   │
           │         │                                   │  (SDK)  │                   │
           │         │                                   └────┬────┘                   │
           │         │                                        │                       │
           │         │  ◄──── stdout: OUTPUT_START ───────────┤                       │
           │         │        {"status":"success",            │                       │
           │         │         "result":"Response text",      │                       │
           │         │         "newSessionId":"sess-xxx"}      │                       │
           │         │        OUTPUT_END                       │                       │
           │         │                                        │                       │
           │    Parse markers                                  │                       │
           │    Save session to DB                             │                       │
           │         │                                        │                       │
           │    channel.sendMessage(jid, result)               │                       │
           │         │                                        │                       │
           │         ▼                                        │                       │
           │    WhatsApp/Slack ◄── response                    │                       │
           │                                                  │                       │
           │    ┌─ IDLE PHASE ────────────────────────────────┤                       │
           │    │                                             │                       │
           │    │  New message arrives?                        │                       │
           │    │    YES → queue.sendMessage()                 │                       │
           │    │           write IPC input file ──→ poll drainIpcInput()              │
           │    │                                    inject into MessageStream         │
           │    │                                    new query ──→ response ───────────┘
           │    │
           │    │  Idle timeout (30min)?
           │    │    YES → queue.closeStdin()
           │    │           write _close sentinel ──→ detect _close
           │    │                                    exit query loop
           │    │                                    container exits
           │    └─────────────────────────────────────────────────────────────
           │
           └──────────────────────────────────────────────────────────────────────────
```

---

## Credential Proxy Flow

```
Container                    Host Proxy (:3001)              Anthropic API
═════════                    ══════════════════              ═════════════

SDK request ──→ http://host.docker.internal:3001/v1/messages
                             │
                        Read request headers
                        Detect auth mode:
                             │
                        ┌────┴────┐
                        │ API Key │  Strip x-api-key: placeholder
                        │  mode   │  Inject x-api-key: REAL_KEY
                        └────┬────┘
                        ┌────┴────┐
                        │  OAuth  │  Strip Authorization: Bearer placeholder
                        │  mode   │  Inject real OAuth token
                        └────┬────┘
                             │
                        Forward to ──→ https://api.anthropic.com/v1/messages
                             │
                        Return response ◄── API response
                             │
SDK receives ◄── proxied response

** Containers NEVER see real credentials **
** Environment only contains: ANTHROPIC_API_KEY=placeholder **
```

---

## Scheduled Task Flow

```
Agent (in container)                Host                           Container (task)
════════════════════                ════                           ════════════════

mcp: schedule_task()
  write IPC file ──→ ipc/{group}/tasks/{id}.json
                             │
                     IPC Watcher (1s poll)
                        parse & validate
                        compute next_run
                        createTask() → DB
                        delete IPC file
                             │
                     Scheduler Loop (60s poll)
                        getDueTasks()
                        WHERE status='active'
                          AND next_run <= NOW
                             │
                        queue.enqueueTask()
                             │
                        runContainerAgent()
                          isScheduledTask: true
                          prompt: "[SCHEDULED TASK]\n{prompt}"
                                                               │
                                                          Execute query
                                                          Stream result
                                                               │
                     Parse output ◄────────────────────── OUTPUT markers
                     channel.sendMessage()
                     logTaskRun() → DB
                     computeNextRun()
                     updateTaskAfterRun()
                        set next_run
                        set last_result
                             │
                     Close container (10s delay)
                     write _close sentinel ──→ container exits
```

---

## IPC Mechanism

The host and container communicate via **filesystem-based IPC**. Each group has an isolated IPC namespace at `data/ipc/{groupFolder}/`.

### Container → Host (async, file-based)

| Directory | Purpose | Processed By |
|-----------|---------|-------------|
| `ipc/{group}/messages/` | send_message tool output | IPC Watcher → channel.sendMessage() |
| `ipc/{group}/tasks/` | schedule/pause/resume/cancel tasks | IPC Watcher → DB operations |

**File format:** `{timestamp}-{random}.json`
```json
{
  "type": "message|schedule_task|pause_task|resume_task|cancel_task",
  "chatJid": "target@s.whatsapp.net",
  "text": "message content",
  "groupFolder": "whatsapp_main",
  "timestamp": "2026-03-20T15:00:00.000Z"
}
```

### Host → Container (polled by agent runner)

| Directory | Purpose | Written By |
|-----------|---------|-----------|
| `ipc/{group}/input/` | Follow-up messages during idle phase | queue.sendMessage() |
| `ipc/{group}/input/_close` | Exit sentinel | queue.closeStdin() |

**Poll interval:** 500ms (drainIpcInput in agent runner)

### Host → Container (snapshots, read-only)

| File | Purpose | Written By |
|------|---------|-----------|
| `ipc/{group}/current_tasks.json` | Task list | writeTasksSnapshot() |
| `ipc/{group}/available_groups.json` | Group list (main only) | writeGroupsSnapshot() |

---

## Container MCP Tools

The agent inside the container has access to these tools via the NanoClaw MCP server:

| Tool | Purpose | Authorization |
|------|---------|--------------|
| `send_message` | Send message to chat immediately | Non-main: own group only. Main: any group |
| `schedule_task` | Create recurring/one-time task | Non-main: own group. Main: any group via target_group_jid |
| `list_tasks` | View scheduled tasks | Non-main: own tasks. Main: all tasks |
| `pause_task` | Pause a task | Non-main: own tasks. Main: any |
| `resume_task` | Resume paused task | Non-main: own tasks. Main: any |
| `cancel_task` | Delete a task | Non-main: own tasks. Main: any |
| `update_task` | Modify task prompt/schedule | Non-main: own tasks. Main: any |
| `register_group` | Register new group | Main only |

---

## Database Schema

**Location:** `store/messages.db` (SQLite)

| Table | Key Columns | Purpose |
|-------|------------|---------|
| `messages` | id, chat_jid, sender, content, timestamp, is_from_me, is_bot_message | Message history |
| `chats` | jid (PK), name, last_message_time, channel, is_group | Chat/group metadata |
| `registered_groups` | jid (PK), name, folder (UNIQUE), trigger_pattern, requires_trigger, is_main, container_config | Group registrations |
| `sessions` | group_folder (PK), session_id | Claude Code session persistence |
| `scheduled_tasks` | id (PK), group_folder, chat_jid, prompt, schedule_type, schedule_value, context_mode, next_run, status | Task definitions |
| `task_run_logs` | id (AI), task_id (FK), run_at, duration_ms, status, result, error | Task execution history |
| `router_state` | key (PK), value | Orchestrator cursors (last_timestamp, etc.) |

---

## Security Model

### Credential Isolation
- Containers receive `ANTHROPIC_API_KEY=placeholder` (never real keys)
- Credential proxy on host injects real credentials per-request
- `.env` file shadowed with `/dev/null` in container mounts

### Filesystem Isolation
- Each group gets its own container with isolated mounts
- Non-main groups cannot see project root or other groups
- Additional mounts validated against `~/.config/nanoclaw/mount-allowlist.json`
- Blocked patterns: `.ssh`, `.gnupg`, `.aws`, `credentials`, `.env`, `id_rsa`, etc.

### IPC Authorization
- Each group has isolated IPC namespace (no cross-group access)
- Non-main groups can only send messages to own group
- Non-main groups can only manage own tasks
- Main group has unrestricted access

### Container Runtime
- Runs as non-root (`node` user, UID mapped to host)
- `docker run --rm` auto-cleans on exit
- Hard timeout prevents stuck containers
- Orphan cleanup on host startup

---

## Key Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `POLL_INTERVAL` | 2000ms | Message discovery loop |
| `SCHEDULER_POLL_INTERVAL` | 60000ms | Task scheduler loop |
| `IDLE_TIMEOUT` | 1800000ms (30min) | Container idle timeout after output |
| `CONTAINER_TIMEOUT` | 1800000ms (30min) | Hard container timeout |
| `MAX_CONCURRENT_CONTAINERS` | 5 | Max simultaneous agent containers |
| `CREDENTIAL_PROXY_PORT` | 3001 | Host proxy port |
| `CONTAINER_IMAGE` | nanoclaw-agent:latest | Docker image name |

---

## Concurrency Model

- **Max 5 concurrent containers** (configurable)
- **Per-group queueing:** messages and tasks queue when limit reached
- **Priority:** tasks > messages when draining queue
- **Retry:** 5 attempts with exponential backoff (5s, 10s, 20s, 40s, 80s)
- **Idle reuse:** containers stay alive for 30min after output, accepting follow-up messages via IPC
- **Task containers:** close 10s after result (no idle waiting)
