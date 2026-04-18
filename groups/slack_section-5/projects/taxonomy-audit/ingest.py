#!/usr/bin/env python3
"""
Taxonomy Vector DB Ingestion Pipeline
Loads taxonomy JSON, builds semantic text per node, embeds into ChromaDB.
"""

import json
import chromadb
from pathlib import Path

TAXONOMY_FILE = "/workspace/ipc/files/taxonomy_export_2026-04-13.json"
DB_PATH = "/workspace/group/projects/taxonomy-audit/vectordb"

def build_semantic_text(node):
    """Build rich semantic text for embedding from node fields."""
    parts = []

    # Node name is primary signal
    parts.append(node["name"])

    # Layer provides categorical context
    parts.append(f"Layer: {node['layer']}")

    # Path gives hierarchical context
    if node.get("path"):
        parts.append(f"Path: {node['path']} > {node['name']}")

    # Aliases are rich semantic signals — each is a way this concept is referenced
    if node.get("aliases") and len(node["aliases"]) > 0:
        # Convert slug-style aliases to readable text
        readable_aliases = [a.replace("-", " ").replace("_", " ") for a in node["aliases"]]
        parts.append(f"Also known as: {', '.join(readable_aliases)}")

    return ". ".join(parts)


def main():
    print("Loading taxonomy...")
    with open(TAXONOMY_FILE) as f:
        nodes = json.load(f)

    print(f"Loaded {len(nodes)} nodes")

    # Layer stats
    layers = {}
    for n in nodes:
        layers[n["layer"]] = layers.get(n["layer"], 0) + 1
    for layer, count in sorted(layers.items()):
        print(f"  {layer}: {count}")

    # Initialize ChromaDB with persistent storage
    print(f"\nInitializing ChromaDB at {DB_PATH}...")
    client = chromadb.PersistentClient(path=DB_PATH)

    # Create collection (or get if exists)
    # Using default embedding function (all-MiniLM-L6-v2)
    collection = client.get_or_create_collection(
        name="taxonomy_nodes",
        metadata={"hnsw:space": "cosine"}  # cosine similarity for semantic comparison
    )

    # Check if already populated
    existing = collection.count()
    if existing > 0:
        print(f"Collection already has {existing} nodes. Clearing for fresh ingest...")
        client.delete_collection("taxonomy_nodes")
        collection = client.create_collection(
            name="taxonomy_nodes",
            metadata={"hnsw:space": "cosine"}
        )

    # Prepare batch data
    ids = []
    documents = []
    metadatas = []

    for node in nodes:
        node_id = str(node["id"])
        semantic_text = build_semantic_text(node)

        metadata = {
            "name": node["name"],
            "layer": node["layer"],
            "parent_id": str(node["parent_id"]) if node.get("parent_id") else "",
            "parent_name": node.get("parent_name") or "",
            "path": node.get("path") or "",
            "child_count": node.get("child_count", 0),
            "alias_count": len(node.get("aliases", [])),
            "depth": len(node["path"].split(">")) + 1 if node.get("path") else 1,
        }

        ids.append(node_id)
        documents.append(semantic_text)
        metadatas.append(metadata)

    # Ingest in batches (ChromaDB limit: 41666 per batch, we have 3307)
    BATCH_SIZE = 500
    total_batches = (len(ids) + BATCH_SIZE - 1) // BATCH_SIZE

    print(f"\nIngesting {len(ids)} nodes in {total_batches} batches...")
    for i in range(0, len(ids), BATCH_SIZE):
        batch_num = i // BATCH_SIZE + 1
        end = min(i + BATCH_SIZE, len(ids))
        collection.add(
            ids=ids[i:end],
            documents=documents[i:end],
            metadatas=metadatas[i:end]
        )
        print(f"  Batch {batch_num}/{total_batches}: nodes {i+1}-{end}")

    # Verify
    final_count = collection.count()
    print(f"\nDone! Collection has {final_count} nodes.")

    # Quick sanity check — query for "artificial intelligence"
    print("\n=== SANITY CHECK: query 'artificial intelligence' ===")
    results = collection.query(
        query_texts=["artificial intelligence machine learning"],
        n_results=5,
        include=["documents", "metadatas", "distances"]
    )
    for i, (doc, meta, dist) in enumerate(zip(
        results["documents"][0], results["metadatas"][0], results["distances"][0]
    )):
        print(f"  [{i+1}] {meta['name']} ({meta['layer']}) — distance: {dist:.4f}")
        print(f"      path: {meta['path'] or '(root)'}")


if __name__ == "__main__":
    main()
