#!/usr/bin/env python3
"""
Parent-Child Nesting Analysis
Detects odd nesting by measuring semantic distance between parent and child nodes.
Flags misplaced nodes and suggests better placements.
"""

import json
import chromadb
from collections import defaultdict

DB_PATH = "/workspace/group/projects/taxonomy-audit/vectordb"
TAXONOMY_FILE = "/workspace/ipc/files/taxonomy_export_2026-04-13.json"
OUTPUT_FILE = "/workspace/group/projects/taxonomy-audit/nesting-report.json"

# Thresholds for parent-child distance (higher = more suspicious)
SUSPICIOUS_THRESHOLD = 0.55   # parent-child are semantically distant
RED_FLAG_THRESHOLD = 0.70     # parent-child are very distant — likely misplaced

BATCH_SIZE = 50


def main():
    print("Loading taxonomy...")
    with open(TAXONOMY_FILE) as f:
        nodes = json.load(f)

    # Build lookup tables
    by_id = {n["id"]: n for n in nodes}
    children_of = defaultdict(list)
    for n in nodes:
        if n.get("parent_id"):
            children_of[n["parent_id"]].append(n)

    print(f"Total nodes: {len(nodes)}")
    print(f"Nodes with parents: {sum(1 for n in nodes if n.get('parent_id'))}")

    # Connect to ChromaDB
    client = chromadb.PersistentClient(path=DB_PATH)
    collection = client.get_collection("taxonomy_nodes")
    print(f"ChromaDB collection: {collection.count()} nodes\n")

    # =============================================
    # 1. PARENT-CHILD SEMANTIC DISTANCE
    # =============================================
    print("=" * 80)
    print("PARENT-CHILD SEMANTIC DISTANCE ANALYSIS")
    print("=" * 80)

    # Get all nodes with parents
    child_nodes = [n for n in nodes if n.get("parent_id") and n["parent_id"] in by_id]
    print(f"\nAnalyzing {len(child_nodes)} parent-child relationships...")

    # Build semantic texts for children (same as ingest.py)
    def build_semantic_text(node):
        parts = [node["name"]]
        parts.append(f"Layer: {node['layer']}")
        if node.get("path"):
            parts.append(f"Path: {node['path']} > {node['name']}")
        if node.get("aliases") and len(node["aliases"]) > 0:
            readable = [a.replace("-", " ").replace("_", " ") for a in node["aliases"]]
            parts.append(f"Also known as: {', '.join(readable)}")
        return ". ".join(parts)

    # For each child, query its parent's embedding distance
    # Strategy: query ChromaDB with child text, filter to parent's ID
    # But ChromaDB doesn't support ID-based filtering well in query mode.
    # Instead: get embeddings for all nodes, compute distances ourselves.

    # Alternative approach: for each child, query ChromaDB for the child's
    # nearest neighbors. If parent is NOT among the top-N nearest, that's suspicious.
    # If parent is very far, that's a red flag.

    # Batch approach: query each child node, get its top-K same-layer neighbors
    # Then check if parent is in those results and what its rank/distance is.

    parent_child_results = []
    misplaced = []

    # Process in batches
    for batch_start in range(0, len(child_nodes), BATCH_SIZE):
        batch = child_nodes[batch_start:batch_start + BATCH_SIZE]
        batch_texts = [build_semantic_text(n) for n in batch]

        # Query: for each child, find its closest same-layer neighbors
        results = collection.query(
            query_texts=batch_texts,
            n_results=20,  # enough to see if parent ranks high
            where={"layer": batch[0]["layer"]} if len(set(n["layer"] for n in batch)) == 1 else None,
            include=["metadatas", "distances"]
        )

        for i, node in enumerate(batch):
            parent = by_id[node["parent_id"]]
            parent_distance = None
            parent_rank = None

            # Find parent in results
            for rank, (meta, dist) in enumerate(zip(
                results["metadatas"][i], results["distances"][i]
            )):
                if meta["name"] == parent["name"] and meta["path"] == (parent.get("path") or ""):
                    parent_distance = dist
                    parent_rank = rank + 1
                    break

            # If parent not in top-20, it's very far
            if parent_distance is None:
                parent_distance = 999  # sentinel — parent not even in top 20
                parent_rank = 999

            # Find the closest non-self neighbor
            closest_neighbor = None
            closest_dist = 999
            for meta, dist in zip(results["metadatas"][i], results["distances"][i]):
                if meta["name"] != node["name"] and dist < closest_dist:
                    closest_neighbor = meta
                    closest_dist = dist

            entry = {
                "node": node["name"],
                "node_id": node["id"],
                "layer": node["layer"],
                "path": node.get("path", ""),
                "parent": parent["name"],
                "parent_id": parent["id"],
                "parent_path": parent.get("path", ""),
                "parent_distance": round(parent_distance, 4) if parent_distance < 900 else None,
                "parent_rank": parent_rank if parent_rank < 900 else None,
                "closest_neighbor": closest_neighbor["name"] if closest_neighbor else None,
                "closest_neighbor_path": closest_neighbor.get("path", "") if closest_neighbor else None,
                "closest_distance": round(closest_dist, 4) if closest_dist < 900 else None,
                "depth": len(node["path"].split(">")) + 1 if node.get("path") else 1,
            }
            parent_child_results.append(entry)

        pct = min(100, int((batch_start + len(batch)) / len(child_nodes) * 100))
        print(f"  ... {pct}%", end="\r", flush=True)

    print("  ... done     ")

    # The batch query above uses same-layer filter only when all nodes in
    # the batch share a layer. Let's redo this properly — query ALL nodes
    # (no layer filter) so parent can be found even in same-layer results.
    print("\nRe-running with no layer filter for accurate parent distances...")

    parent_child_results = []
    for batch_start in range(0, len(child_nodes), BATCH_SIZE):
        batch = child_nodes[batch_start:batch_start + BATCH_SIZE]
        batch_texts = [build_semantic_text(n) for n in batch]

        results = collection.query(
            query_texts=batch_texts,
            n_results=30,
            include=["metadatas", "distances"]
        )

        for i, node in enumerate(batch):
            parent = by_id[node["parent_id"]]
            parent_distance = None
            parent_rank = None

            for rank, (meta, dist) in enumerate(zip(
                results["metadatas"][i], results["distances"][i]
            )):
                # Match by name + layer (parent is always same layer)
                if meta["name"] == parent["name"] and meta["layer"] == parent["layer"]:
                    parent_distance = dist
                    parent_rank = rank + 1
                    break

            if parent_distance is None:
                parent_distance_val = None
                parent_rank_val = None
            else:
                parent_distance_val = round(parent_distance, 4)
                parent_rank_val = parent_rank

            # Find closest non-self, non-parent neighbor
            closest_neighbor = None
            closest_dist = 999
            for meta, dist in zip(results["metadatas"][i], results["distances"][i]):
                if meta["name"] != node["name"] and dist < closest_dist:
                    closest_neighbor = meta
                    closest_dist = dist

            # Determine if this is a "better parent" candidate
            better_parent = None
            if parent_distance_val is not None and closest_neighbor:
                if closest_dist < parent_distance_val * 0.6:  # 40% closer than actual parent
                    better_parent = {
                        "name": closest_neighbor["name"],
                        "layer": closest_neighbor["layer"],
                        "path": closest_neighbor.get("path", ""),
                        "distance": round(closest_dist, 4),
                    }

            entry = {
                "node": node["name"],
                "node_id": node["id"],
                "layer": node["layer"],
                "path": node.get("path", ""),
                "parent": parent["name"],
                "parent_id": parent["id"],
                "parent_path": parent.get("path", ""),
                "parent_distance": parent_distance_val,
                "parent_rank": parent_rank_val,
                "closest_neighbor": closest_neighbor["name"] if closest_neighbor else None,
                "closest_neighbor_path": closest_neighbor.get("path", "") if closest_neighbor else None,
                "closest_distance": round(closest_dist, 4) if closest_dist < 900 else None,
                "better_parent": better_parent,
                "depth": len(node["path"].split(">")) + 1 if node.get("path") else 1,
            }
            parent_child_results.append(entry)

        pct = min(100, int((batch_start + len(batch)) / len(child_nodes) * 100))
        print(f"  ... {pct}%", end="\r", flush=True)

    print("  ... done     ")

    # =============================================
    # 2. CLASSIFY RESULTS
    # =============================================

    # Nodes where parent wasn't found in top-30 nearest
    orphan_like = [r for r in parent_child_results if r["parent_distance"] is None]

    # Nodes where parent was found but is distant
    found = [r for r in parent_child_results if r["parent_distance"] is not None]
    suspicious = sorted(
        [r for r in found if r["parent_distance"] >= SUSPICIOUS_THRESHOLD],
        key=lambda x: -x["parent_distance"]
    )
    red_flags = [r for r in suspicious if r["parent_distance"] >= RED_FLAG_THRESHOLD]

    # Nodes with a significantly better parent candidate
    better_home = [r for r in parent_child_results if r["better_parent"] is not None]

    # =============================================
    # 3. INVERTED ABSTRACTION CHECK
    # =============================================
    # A leaf node that is MORE general than its parent is suspicious.
    # Heuristic: if child has more aliases or shorter name, and parent is deeper,
    # the hierarchy might be inverted.
    print("\nChecking for inverted abstractions...")

    inverted = []
    for n in nodes:
        if not n.get("parent_id") or n["parent_id"] not in by_id:
            continue
        parent = by_id[n["parent_id"]]
        # Child has significantly more aliases (broader concept)
        child_aliases = len(n.get("aliases", []))
        parent_aliases = len(parent.get("aliases", []))
        # Child has more children than parent's other children
        child_children = n.get("child_count", 0)

        if child_aliases > parent_aliases * 2 and child_aliases > 10:
            inverted.append({
                "node": n["name"],
                "node_aliases": child_aliases,
                "node_children": child_children,
                "parent": parent["name"],
                "parent_aliases": parent_aliases,
                "layer": n["layer"],
                "path": n.get("path", ""),
            })

    inverted.sort(key=lambda x: -x["node_aliases"])

    # =============================================
    # 4. DEPTH ANOMALIES
    # =============================================
    print("Checking depth anomalies...")

    # Nodes at unusual depth for their layer
    layer_depths = defaultdict(list)
    for r in parent_child_results:
        layer_depths[r["layer"]].append(r["depth"])

    depth_stats = {}
    for layer, depths in layer_depths.items():
        avg = sum(depths) / len(depths)
        std = (sum((d - avg) ** 2 for d in depths) / len(depths)) ** 0.5
        depth_stats[layer] = {"avg": round(avg, 2), "std": round(std, 2), "max": max(depths)}

    deep_outliers = []
    for r in parent_child_results:
        stats = depth_stats[r["layer"]]
        if r["depth"] > stats["avg"] + 2 * stats["std"]:
            deep_outliers.append(r)

    # =============================================
    # PRINT RESULTS
    # =============================================
    print(f"\n{'=' * 80}")
    print("RESULTS SUMMARY")
    print(f"{'=' * 80}")
    print(f"\nTotal parent-child pairs analyzed: {len(parent_child_results)}")
    print(f"Parent not in top-30 neighbors:    {len(orphan_like)} (very distant)")
    print(f"Suspicious (dist >= {SUSPICIOUS_THRESHOLD}):        {len(suspicious)}")
    print(f"Red flags (dist >= {RED_FLAG_THRESHOLD}):           {len(red_flags)}")
    print(f"Better parent candidate found:     {len(better_home)}")
    print(f"Inverted abstractions:             {len(inverted)}")
    print(f"Depth outliers:                    {len(deep_outliers)}")

    print(f"\nDepth stats per layer:")
    for layer, stats in sorted(depth_stats.items()):
        print(f"  {layer}: avg={stats['avg']}, std={stats['std']}, max={stats['max']}")

    # Top orphan-like
    if orphan_like:
        print(f"\n{'=' * 80}")
        print(f"TOP 'ORPHAN-LIKE' NODES (parent not in top-30 nearest)")
        print(f"{'=' * 80}")
        for r in orphan_like[:20]:
            print(f"\n  [{r['layer']}] {r['node']}")
            print(f"    Parent: {r['parent']} (path: {r['parent_path'] or '(root)'})")
            print(f"    Path:   {r['path'] or '(root)'}")
            if r["closest_neighbor"]:
                print(f"    Nearest: {r['closest_neighbor']} (dist={r['closest_distance']})")

    # Top red flags
    if red_flags:
        print(f"\n{'=' * 80}")
        print(f"TOP RED FLAGS (parent distance >= {RED_FLAG_THRESHOLD})")
        print(f"{'=' * 80}")
        for r in red_flags[:20]:
            print(f"\n  [{r['layer']}] {r['node']}  →  parent dist: {r['parent_distance']}")
            print(f"    Parent: {r['parent']} (path: {r['parent_path'] or '(root)'})")
            print(f"    Path:   {r['path'] or '(root)'}")
            if r["better_parent"]:
                bp = r["better_parent"]
                print(f"    BETTER FIT: {bp['name']} ({bp['layer']}) dist={bp['distance']} (path: {bp['path'] or '(root)'})")

    # Top better-home candidates
    if better_home:
        print(f"\n{'=' * 80}")
        print(f"TOP 'BETTER HOME' CANDIDATES (closest neighbor 40%+ closer than parent)")
        print(f"{'=' * 80}")
        sorted_bh = sorted(better_home, key=lambda x: x["better_parent"]["distance"])
        for r in sorted_bh[:25]:
            bp = r["better_parent"]
            savings = r["parent_distance"] - bp["distance"] if r["parent_distance"] else 0
            print(f"\n  [{r['layer']}] {r['node']}")
            print(f"    Current parent: {r['parent']} (dist={r['parent_distance']})")
            print(f"    Better fit:     {bp['name']} ({bp['layer']}) (dist={bp['distance']}, saves {savings:.3f})")
            print(f"    Path now:       {r['path'] or '(root)'}")
            print(f"    Better path:    {bp['path'] or '(root)'}")

    # Inverted abstractions
    if inverted:
        print(f"\n{'=' * 80}")
        print(f"INVERTED ABSTRACTIONS (child broader than parent)")
        print(f"{'=' * 80}")
        for r in inverted[:15]:
            print(f"\n  [{r['layer']}] {r['node']} ({r['node_aliases']} aliases, {r['node_children']} children)")
            print(f"    Under parent: {r['parent']} ({r['parent_aliases']} aliases)")
            print(f"    Path: {r['path'] or '(root)'}")

    # =============================================
    # SAVE FULL REPORT
    # =============================================
    report = {
        "summary": {
            "total_pairs": len(parent_child_results),
            "orphan_like": len(orphan_like),
            "suspicious": len(suspicious),
            "red_flags": len(red_flags),
            "better_home_candidates": len(better_home),
            "inverted_abstractions": len(inverted),
            "depth_outliers": len(deep_outliers),
        },
        "depth_stats": depth_stats,
        "thresholds": {
            "suspicious": SUSPICIOUS_THRESHOLD,
            "red_flag": RED_FLAG_THRESHOLD,
        },
        "orphan_like": orphan_like,
        "red_flags": red_flags[:50],
        "suspicious": suspicious[:100],
        "better_home": sorted(better_home, key=lambda x: x["better_parent"]["distance"])[:100],
        "inverted_abstractions": inverted,
        "depth_outliers": deep_outliers,
        "all_pairs": parent_child_results,  # full data for further analysis
    }

    with open(OUTPUT_FILE, "w") as f:
        json.dump(report, f, indent=2)
    print(f"\n\nFull report saved to: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
