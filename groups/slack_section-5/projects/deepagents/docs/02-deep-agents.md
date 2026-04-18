# Deep Agents — Compact Reference (April 2026)

> Released Feb 11, 2026 — Open-source SDK (MIT) by LangChain
> Built on LangGraph. Inspired by Claude Code and Deep Research.
> GitHub: `langchain-ai/deepagents` | Version: v0.5.0 alpha

---

## What Makes an Agent "Deep"

| Shallow Agent | Deep Agent |
|--------------|------------|
| Simple LLM-in-a-loop | Explicit planning + task decomposition |
| Single context window | Context isolation via subagents + files |
| Reactive tool calling | Proactive planning with `write_todos` |
| Stateless between turns | Persistent memory + checkpointing |
| One agent, one task | Hierarchical multi-agent orchestration |

### Four Pillars
1. *Detailed system prompts* — complex instructions, few-shot examples
2. *Planning tools* — `write_todos` for structured task decomposition
3. *Subagents* — spawn specialized workers with isolated context
4. *Filesystem* — shared workspace for persistent memory and large outputs

---

## Built-In Tools

### Planning & Orchestration
| Tool | Purpose |
|------|---------|
| `write_todos` | Decompose tasks, track progress, adapt plans |
| `task` | Spawn subagent with isolated context |

### Filesystem
| Tool | Purpose |
|------|---------|
| `read_file` | Read without flooding context |
| `write_file` | Persistent output storage |
| `edit_file` | Modify existing files |
| `ls` / `glob` / `grep` | Navigate and search workspace |

### Execution
| Tool | Purpose |
|------|---------|
| `execute` | Run shell commands (sandboxed) |

---

## Multi-Agent Orchestration Patterns

### 1. Supervisor
One LLM routes tasks to specialized agents:
```
Supervisor (LLM)
  ├── Tool: "call_research_agent"
  ├── Tool: "call_writing_agent"
  └── Tool: "call_analysis_agent"
```
Best for: clear task routing, centralized control.

### 2. Hierarchical
Multi-level supervisors managing domain teams:
```
Top Supervisor
  ├── Research Team Supervisor
  │   ├── Web Search Agent
  │   └── Document Analysis Agent
  └── Writing Team Supervisor
      ├── Content Generator
      └── Editor Agent
```
Best for: complex domains, team structure, independent scaling.

### 3. Handoff
Agents transfer control explicitly via tool calls:
```
Agent A ──handoff──→ Agent B ──handoff──→ Agent C
                                         └──respond──→ User
```
Best for: fluid collaboration, sequential expertise.

### 4. Swarm
Agents dynamically route based on specialization:
- System tracks last active agent
- Each agent decides who handles next
Best for: dynamic, expertise-based routing.

### 5. Scatter-Gather
Distribute to many, consolidate results:
```python
def fan_out(state):
    return [Send("researcher", {"query": q}) for q in state["queries"]]
```
Best for: parallel processing, research synthesis.

---

## Code Patterns

### State Definition
```python
from typing import Annotated, TypedDict
from langgraph.graph.message import add_messages

class AgentState(TypedDict):
    messages: Annotated[list, add_messages]
    plan: list[str]
    results: Annotated[list[str], operator.add]
```

### Node Function
```python
def research_node(state: AgentState) -> dict:
    result = llm.invoke(state["messages"])
    return {"messages": [result]}
```

### Command — Update + Route
```python
from langgraph.types import Command

def tool_node(state: AgentState) -> Command:
    return Command(
        update={"results": [extracted]},
        goto="synthesize"
    )
```

### Tool Integration
```python
from langgraph.prebuilt import ToolNode

tools = [search, calculator, writer]
tool_node = ToolNode(tools)
graph.add_node("tools", tool_node)
```

### Subgraph as Node
```python
# Different state schemas — wrap in function
def call_sub(state: ParentState) -> dict:
    out = subgraph.invoke({"query": state["input"]})
    return {"results": out["response"]}

# Same state schema — add directly
graph.add_node("specialist", compiled_subgraph)
```

### Interrupt for Human Review
```python
response = interrupt("Review these findings before publishing?")
# ... user resumes with Command(resume="approved")
```

---

## Subgraph Persistence Modes

| Mode | Use Case |
|------|----------|
| **Per-invocation** (default) | Most cases, supports interrupts |
| **Per-thread** | Multi-turn subagents building context |
| **Stateless** | Plain function, no checkpointing |

---

## Production Notes

- >75% of multi-agent systems become hard to manage past 5 agents
- Budget 10-20% infra overhead for persistent state
- 2-4 week ramp-up for graph-based thinking
- Use LangSmith for observability — essential at scale
- Model-agnostic: works with any tool-calling LLM
- Pluggable storage: in-memory → local disk → LangGraph stores → sandboxes

---

## Typical Deep Agent Flow

```
1. Receive task
   ↓
2. Plan (write_todos)
   ↓
3. Execute step → [needs specialist?] → spawn subagent
   ↓                                        ↓
4. Tool calls ←──────────────── subagent returns
   ↓
5. Check progress → [more steps?] → loop to 3
   ↓
6. [Critical decision?] → interrupt → human review
   ↓
7. Synthesize & deliver
```

---

## Key Takeaway

Deep Agents = LangGraph + planning discipline + context isolation + subagent spawning.

It's the pattern that makes agents work on *real* multi-step tasks instead of toy demos.
