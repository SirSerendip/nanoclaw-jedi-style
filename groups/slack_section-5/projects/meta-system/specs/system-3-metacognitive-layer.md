# System 3 — Metacognitive Layer (SPEC DRAFT)
> Status: draft | Priority: P2 | Date: 2026-04-10
> Decision: Deferred — needs S2 baseline before implementation

---

## Definition

S3 = the layer that watches S1 and S2 play the game, and changes the rules when the game is no longer optimal.

- S1 (Reflex): fires at session start, loads CLAUDE.md — reactive
- S2 (Orchestration): project.sh + memory.db + protocols — procedural
- S3 (Metacognition): observes system performance over time — evolutionary

## Components

| Component | Function | Mechanism |
|---|---|---|
| Drift Detector | Divergence between STATUS.md and actual state | Scheduled diff: checkpoint vs workspace |
| Protocol Auditor | Check protocol compliance across sessions | Parse session logs for skip patterns |
| Memory Hygiene Engine | Stale/contradictory/redundant memory cleanup | Cross-reference memory table with code |
| Lens Evaluator | Assess lens strategic value per project | Compare session outputs with/without lens |
| Evolution Proposer | Generate protocol improvement candidates | Pattern analysis + tension zone monitoring |

## Constraint
S3 proposes, never enacts without human approval. Principal retains veto. Non-negotiable.

## Evolution Paths

```
Path A: Scheduled audit task (NanoClaw cron) — implementable NOW
  └→ Path C: Protocol Mutation Engine (rule fitness scoring)
Path B: Ludor-persistent per session (session-end self-assessment)
  └→ Path D: Multi-Agent Coordinator (cross-project dependencies)
Paths C+D → Path E: Autonomous Governance Layer (endgame)
```

## Path A — Minimal Viable S3

1. Audit script (bash): checkpoint age, STATUS.md freshness, memory count, session-end compliance
2. NanoClaw scheduled task with script gate (wakeAgent only on drift)
3. Agent wakes with Ludor lens, produces structured health report
4. Human reviews in channel

## Prerequisites Before Implementation

- [ ] Establish S2 baseline metrics (session count, protocol compliance rate, drift frequency)
- [ ] Run S2 unmodified for N sessions to gather comparison data
- [ ] Define success criteria for S3 (what "better" looks like, measurably)
- [ ] Pre-compact hook must be wired (Curtis/NanoClaw dependency)

## Nash Equilibrium Analysis

| State | Equilibrium | Stability |
|---|---|---|
| Current (S1+S2) | Static — rules don't adapt | Stable but brittle |
| S3 Path A | Monitoring | More stable — detects drift |
| S3 Path B | Reflective | Adaptive per session |
| S3 Path C | Evolutionary | Self-correcting protocols |
| S3 Path E | Dynamic cooperative | Anti-fragile |
