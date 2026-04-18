# InstantGameApp — STATUS
> Source of truth. Updated at each pause. Derived from code, not memory.
> Last updated: 2026-04-12 | Version: 0.1-concept

---

## MISSION

Intent-to-playable innovation game in <5 minutes.
JOTF's core differentiator: on-the-fly game creation at speed of user intent.

---

## ARCHITECTURE

| Component | Type | Role |
|---|---|---|
| Jedi Signals | Backend (existing) | Pure innovation signal repository |
| JediGate | Backend (existing) | PHP proxy for all LLM calls — centralized auth, prompt resiliency, logging, perf monitoring |
| JediGate-SDK | Middleware (existing) | Tools for JediGate capabilities — prompt orchestration, etc. |
| Ludor (platform) | Dev container (existing) | Game composition platform — branded opening screens, consistent game dynamics |
| InstantGameApp | This project | Orchestration layer — rapid intent→game pipeline tying all components together |

---

## FEATURES — STATE

| Feature | Status | Notes |
|---|---|---|
| Intent capture | 📋 Design | User declares what game they want |
| Game generation pipeline | 📋 Design | Intent → game template → playable output |
| Signal integration | 📋 Design | Pull relevant innovation signals into game content |
| Ludor composition | 📋 Design | Leverage Ludor struts for branded, consistent output |
| <5 min target | 🎯 Goal | End-to-end from intent declaration to playable game |

---

## EXISTING ECOSYSTEM

| System | Status | Integration Need |
|---|---|---|
| Jedi Signals | ✅ Live | Signal sourcing for game content |
| JediGate | ✅ Live | LLM call proxy, auth, logging |
| JediGate-SDK | ✅ Live | Prompt orchestration middleware |
| Ludor | ✅ Live | Game scaffold, branding, dynamics |

---

## KNOWN DEBT

| Item | Severity | Detail |
|---|---|---|
| Architecture mapping | ⚠️ | Need full audit of existing components + integration points |
| Pipeline design | ⚠️ | No defined flow from intent → playable game yet |

---

## DATA FILES

| File | Role | State |
|---|---|---|
| — | — | — |
