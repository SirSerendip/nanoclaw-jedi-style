#!/usr/bin/env python3
"""
Cross-layer semantic overlap analysis — batch optimized.
Finds nodes semantically close but in different layers (refactoring candidates).
"""

import json
import sys
import chromadb
from collections import defaultdict

DB_PATH = "/workspace/group/projects/taxonomy-audit/vectordb"
TAXONOMY_FILE = "/workspace/ipc/files/taxonomy_export_2026-04-13.json"
OUTPUT_FILE = "/workspace/group/projects/taxonomy-audit/overlap-report.json"

CLOSE_THRESHOLD = 0.35
VERY_CLOSE_THRESHOLD = 0.25
BATCH_SIZE = 50  # query batch size

def batch_query(collection, docs, layer_filter, n_results=5):
    """Query in batches to avoid memory issues."""
    all_results = []
    for i in range(0, len(docs), BATCH_SIZE):
        batch = docs[i:i+BATCH_SIZE]
        results = collection.query(
            query_texts=batch,
            n_results=n_results,
            where={"layer": layer_filter},
            include=["metadatas", "distances"]
        )
        for j in range(len(batch)):
            all_results.append({
                "metadatas": results["metadatas"][j],
                "distances": results["distances"][j],
            })
        pct = min(100, int((i + len(batch)) / len(docs) * 100))
        print(f"    ... {pct}%", end="\r", flush=True)
    print("    ... done     ")
    return all_results

def main():
    with open(TAXONOMY_FILE) as f:
        nodes = json.load(f)

    client = chromadb.PersistentClient(path=DB_PATH)
    collection = client.get_collection("taxonomy_nodes")
    print(f"Collection: {collection.count()} nodes\n")

    layers = ["technology", "application", "catalyst", "trend"]
    layer_data = {}
    for layer in layers:
        result = collection.get(where={"layer": layer}, include=["documents", "metadatas"])
        layer_data[layer] = {
            "ids": result["ids"],
            "docs": result["documents"],
            "metas": result["metadatas"],
        }
        print(f"  {layer}: {len(result['ids'])} nodes")

    # =============================================
    # CROSS-LAYER ANALYSIS
    # =============================================
    print("\n" + "="*80)
    print("CROSS-LAYER OVERLAP ANALYSIS")
    print("="*80)

    overlap_report = []
    layer_pair_stats = {}
    all_overlaps = []  # for JSON export

    for i, layer_a in enumerate(layers):
        for layer_b in layers[i+1:]:
            pair_key = f"{layer_a} <> {layer_b}"
            print(f"\n  Analyzing: {pair_key} ({len(layer_data[layer_a]['docs'])} vs {len(layer_data[layer_b]['docs'])} nodes)")

            results = batch_query(
                collection,
                layer_data[layer_a]["docs"],
                layer_b,
                n_results=3
            )

            close_pairs = []
            for idx, res in enumerate(results):
                meta_a = layer_data[layer_a]["metas"][idx]
                for match_meta, dist in zip(res["metadatas"], res["distances"]):
                    if dist < CLOSE_THRESHOLD:
                        close_pairs.append({
                            "node_a": meta_a["name"],
                            "layer_a": layer_a,
                            "path_a": meta_a["path"] or "(root)",
                            "node_b": match_meta["name"],
                            "layer_b": layer_b,
                            "path_b": match_meta["path"] or "(root)",
                            "distance": round(dist, 4),
                        })

            # Deduplicate
            seen = set()
            unique = []
            for p in sorted(close_pairs, key=lambda x: x["distance"]):
                key = tuple(sorted([p["node_a"], p["node_b"]]))
                if key not in seen:
                    seen.add(key)
                    unique.append(p)

            very_close_count = len([p for p in unique if p["distance"] < VERY_CLOSE_THRESHOLD])
            layer_pair_stats[pair_key] = {"total": len(unique), "very_close": very_close_count}

            if unique:
                overlap_report.append((pair_key, unique))
                all_overlaps.extend(unique)

    # Summary table
    print("\n--- SUMMARY: Cross-Layer Overlap Counts ---")
    print(f"{'Layer Pair':<35} {'Close (<0.35)':<15} {'Very Close (<0.25)'}")
    print("-" * 65)
    for pair, stats in sorted(layer_pair_stats.items(), key=lambda x: -x[1]["total"]):
        print(f"{pair:<35} {stats['total']:<15} {stats['very_close']}")

    # Top overlaps per pair
    for pair_key, pairs in sorted(overlap_report, key=lambda x: -len(x[1])):
        print(f"\n{'='*80}")
        print(f"  {pair_key} — {len(pairs)} overlaps")
        print(f"{'='*80}")
        for p in pairs[:15]:
            sev = "RED" if p["distance"] < VERY_CLOSE_THRESHOLD else "YLW"
            print(f"\n  [{sev}] dist={p['distance']:.4f}")
            print(f"     [{p['layer_a']}] {p['node_a']}  |  path: {p['path_a']}")
            print(f"     [{p['layer_b']}] {p['node_b']}  |  path: {p['path_b']}")
        if len(pairs) > 15:
            print(f"\n  ... and {len(pairs) - 15} more")

    # =============================================
    # WITHIN-LAYER ANALYSIS
    # =============================================
    print("\n\n" + "="*80)
    print("WITHIN-LAYER OVERLAP ANALYSIS (same layer, different subtree)")
    print("="*80)

    within_overlaps_all = []

    for layer in layers:
        print(f"\n  Analyzing: {layer} ({len(layer_data[layer]['docs'])} nodes)")

        results = batch_query(
            collection,
            layer_data[layer]["docs"],
            layer,
            n_results=6  # extra since first result is self
        )

        within = []
        for idx, res in enumerate(results):
            meta_a = layer_data[layer]["metas"][idx]
            for match_meta, dist in zip(res["metadatas"], res["distances"]):
                if match_meta["name"] == meta_a["name"]:
                    continue
                if dist < CLOSE_THRESHOLD:
                    root_a = (meta_a["path"] or meta_a["name"]).split(">")[0].strip()
                    root_b = (match_meta["path"] or match_meta["name"]).split(">")[0].strip()
                    if root_a != root_b:
                        within.append({
                            "node_a": meta_a["name"],
                            "root_a": root_a,
                            "path_a": meta_a["path"] or "(root)",
                            "node_b": match_meta["name"],
                            "root_b": root_b,
                            "path_b": match_meta["path"] or "(root)",
                            "layer": layer,
                            "distance": round(dist, 4),
                        })

        seen = set()
        unique = []
        for p in sorted(within, key=lambda x: x["distance"]):
            key = tuple(sorted([p["node_a"], p["node_b"]]))
            if key not in seen:
                seen.add(key)
                unique.append(p)

        very_close = [p for p in unique if p["distance"] < VERY_CLOSE_THRESHOLD]
        print(f"  {layer.upper()}: {len(unique)} cross-subtree overlaps ({len(very_close)} very close)")

        for p in unique[:10]:
            sev = "RED" if p["distance"] < VERY_CLOSE_THRESHOLD else "YLW"
            print(f"\n  [{sev}] dist={p['distance']:.4f}")
            print(f"     [{p['root_a']}] {p['node_a']}  |  path: {p['path_a']}")
            print(f"     [{p['root_b']}] {p['node_b']}  |  path: {p['path_b']}")

        if len(unique) > 10:
            print(f"\n  ... and {len(unique) - 10} more")

        within_overlaps_all.extend(unique)

    # Save full report as JSON
    report = {
        "cross_layer": {
            "summary": layer_pair_stats,
            "overlaps": all_overlaps,
        },
        "within_layer": within_overlaps_all,
        "thresholds": {
            "close": CLOSE_THRESHOLD,
            "very_close": VERY_CLOSE_THRESHOLD,
        },
        "total_nodes": len(nodes),
    }
    with open(OUTPUT_FILE, "w") as f:
        json.dump(report, f, indent=2)
    print(f"\n\nFull report saved to: {OUTPUT_FILE}")
    print(f"Total cross-layer overlaps: {len(all_overlaps)}")
    print(f"Total within-layer overlaps: {len(within_overlaps_all)}")


if __name__ == "__main__":
    main()
