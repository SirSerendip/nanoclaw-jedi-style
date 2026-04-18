# Taxonomy-Audit — STATUS
> Source of truth. Updated at each pause. Derived from code, not memory.
> Last updated: 2026-04-13 | Version: 0.2-analysis

---

## MISSION

Audit and improve the Jedi Signals taxonomy tree using vector similarity analysis.
Goal: minimize semantic overlap across the 4 layers (technology, application, catalyst, trend).

---

## ARCHITECTURE

| Component | Type | Role |
|---|---|---|
| ChromaDB | Vector DB (local) | Persistent vector store at `vectordb/` |
| all-MiniLM-L6-v2 | Embedding model | Sentence transformer for semantic embeddings |
| ingest.py | Pipeline | Loads JSON → builds semantic text → embeds into ChromaDB |
| analyze.py | Analysis | Batch cross-layer + within-layer overlap detection |
| overlap-report.json | Output | Full structured overlap data (892 cross + 639 within) |

---

## TAXONOMY STATS

| Layer | Nodes | Root Categories |
|---|---|---|
| application | 1,588 | 23 |
| catalyst | 743 | 5 |
| technology | 700 | 10 |
| trend | 276 | 12 |
| *Total* | *3,307* | *52* |

Depth: up to 6 levels. Aliases: 11,583 total (~3.5/node avg).

---

## ANALYSIS RESULTS

| Layer Pair | Close (<0.35) | Very Close (<0.25) |
|---|---|---|
| technology <> application | 287 | 6 |
| application <> catalyst | 284 | 15 |
| application <> trend | 153 | 7 |
| catalyst <> trend | 81 | 11 |
| technology <> catalyst | 53 | 1 |
| technology <> trend | 34 | 0 |
| *Cross-layer total* | *892* | *40* |

| Within-Layer | Cross-subtree overlaps | Very Close |
|---|---|---|
| application | 410 | 62 |
| technology | 115 | 26 |
| catalyst | 95 | 16 |
| trend | 19 | 0 |
| *Within-layer total* | *639* | *104* |

---

## FEATURES — STATE

| Feature | Status | Notes |
|---|---|---|
| Vector DB setup | ✅ Done | ChromaDB + MiniLM embeddings, 3307 nodes ingested |
| Cross-layer analysis | ✅ Done | 892 overlaps found, 40 very close |
| Within-layer analysis | ✅ Done | 639 cross-subtree overlaps, 104 very close |
| Refactoring recommendations | 📋 Pending | Awaiting Curtis's criteria + priorities |

---

## KNOWN DEBT

| Item | Severity | Detail |
|---|---|---|
| Python packages ephemeral | ⚠️ | ChromaDB + pip lost between sessions, need reinstall |
| sqlite3 shim ephemeral | ⚠️ | Same /home/node/bin issue as other projects |

---

## DATA FILES

| File | Role | State |
|---|---|---|
| ingest.py | Embedding pipeline | ✅ Working |
| analyze.py | Overlap analysis | ✅ Working |
| vectordb/ | ChromaDB persistent store | ✅ 3307 nodes |
| overlap-report.json | Full analysis output | ✅ Generated |
