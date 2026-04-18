# LangChain Universe — Compact Reference (April 2026)

## Package Map

| Package | Role | Version |
|---------|------|---------|
| **langchain-core** | Foundational abstractions (Runnables, Messages, Prompts) | v0.3+ |
| **langchain** | High-level APIs, `create_agent()`, chains, RAG | v0.3+ |
| **langchain-community** | Third-party integrations (loaders, vector stores, LLMs) | v0.4+ |
| **langgraph** | Stateful graph-based agent orchestration | v1.1+ |
| **langsmith** | Observability, tracing, evaluation | — |
| **langsmith-deployment** | Production deployment (ex-LangGraph Platform) | GA |
| **langserve** | Wrap Runnables as FastAPI endpoints | — |
| **deepagents** | Multi-step agent harness (planning, subagents) | v0.5.0α |

### How They Relate

```
langchain-core          ← foundation (Runnables, LCEL, Messages)
    ├── langchain       ← high-level agents, chains, RAG
    ├── langchain-community  ← 3rd-party integrations
    └── langgraph       ← stateful graph orchestration
            └── deepagents  ← structured multi-step agent runtime

langsmith               ← observability layer (traces, evals)
langsmith-deployment    ← production hosting (Cloud / Hybrid / Self-hosted)
langserve               ← simple Runnable → API (not for agents)
```

---

## Core Abstractions

### Runnables — The Universal Protocol
Every component is a Runnable. Interface: `.invoke()`, `.batch()`, `.stream()` + async variants.

### LCEL (LangChain Expression Language)
Declarative pipe composition:
```python
chain = prompt | model | parser     # RunnableSequence
```

### Key Building Blocks

| Abstraction | What It Does |
|-------------|-------------|
| **Runnables** | Universal interface for all components |
| **LCEL** | Pipe-based composition (`prompt \| model \| parser`) |
| **Tools** | Callable functions agents can invoke |
| **Retrievers** | Query external data (vector stores, DBs) |
| **Memory** | Short-term (conversation) + long-term (episodic) |
| **Output Parsers** | Structure LLM output into typed objects |

---

## LangGraph — The Agent Engine

### Core Primitives

| Primitive | Description |
|-----------|-------------|
| **State** | Shared TypedDict/Pydantic representing agent snapshot |
| **Nodes** | Python functions — receive state, return updates |
| **Edges** | Fixed or conditional connections between nodes |
| **Send** | Dynamic parallel dispatch (map-reduce) |
| **Command** | State update + routing in one return |

### Execution Model
- Message-passing inspired by Google Pregel
- Runs in "super-steps" — nodes execute in parallel until quiescent
- Recursion limit: 1000 steps default

### State with Reducers
```python
class AgentState(TypedDict):
    messages: Annotated[list[AnyMessage], add_messages]  # accumulate
    results: Annotated[list[str], operator.add]           # concatenate
    approval: bool                                         # overwrite (default)
```

### The Agent Loop
```
START → LLM Node → [tool calls?] → YES → Tool Node → loop back
                                  → NO  → END
```

### Conditional Routing
```python
def should_continue(state):
    if state["messages"][-1].tool_calls:
        return "call_tools"
    return "end"

graph.add_conditional_edges("llm", should_continue)
```

### Why LangGraph Over Classic Agents
- Classic agents: simple tool-calling loops, break on multi-step stateful tasks
- LangGraph: explicit state, long-running workflows, human-in-the-loop, durable execution, checkpointing

---

## Persistence & Memory

| Type | Scope | Use Case |
|------|-------|----------|
| **Short-term** | Thread-scoped (checkpointer) | Conversation history within a session |
| **Long-term** | Cross-thread (Memory Store) | User preferences, facts, across sessions |
| **Checkpoints** | Every step | Time-travel, fault tolerance, HITL |

Backends: MemorySaver (dev), PostgreSQL/Redis (prod).

---

## Human-in-the-Loop

```python
# Pause
response = interrupt("Approve this action?")

# Resume
graph.invoke(Command(resume="approved"), config={"configurable": {"thread_id": tid}})
```

Also: `interrupt_before` / `interrupt_after` for static breakpoints.

---

## Deployment Stack

| Tier | Model | Notes |
|------|-------|-------|
| **Cloud** | Fully managed SaaS | Zero maintenance, Plus+ plans |
| **Hybrid (BYOC)** | SaaS control plane + your VPC | Enterprise only |
| **Self-hosted** | Full control | 100k free monthly executions (dev tier) |

Includes: LangGraph Studio (visual debugger), 30+ API endpoints, horizontal scaling.

---

## MCP Integration
- Standardized tool protocol ("USB port for agents")
- `langchain-mcp-adapters` — plug any MCP server into LangGraph agents
- Agents can expose themselves as MCP servers
- Multi-server support for combining tool sets

---

## Learning Path

1. Runnables + LCEL → basic composition
2. `create_agent()` or custom LangGraph → agent loops
3. LangSmith → tracing and evaluation
4. LangSmith Deployment → production hosting
5. Deep Agents → complex multi-step, long-context tasks
