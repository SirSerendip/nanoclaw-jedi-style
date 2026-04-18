#!/usr/bin/env node
/**
 * search.mjs — Semantic search over the JOTF Shared Library.
 *
 * Usage:
 *   node search.mjs "moat strategy"
 *   node search.mjs --top 10 "brand decisions"
 *   node search.mjs --category lesson "SVG rendering"
 *   node search.mjs --category decision,lesson "pricing"
 *   node search.mjs --origin slack_meetos "action items"
 *   node search.mjs --author "Curtis" "background"
 *   node search.mjs --date "2026-04" "Q2 planning"
 *   node search.mjs --tags "moat" "competitive advantage"
 *   node search.mjs --section "decisions" "authentication"
 *   node search.mjs --verbose "deferred decisions"
 *
 * Categories: lesson, decision, contact, transcript, analysis, backstory, journal, archive, misc
 */

import fs from 'fs';
import path from 'path';
import Database from 'better-sqlite3';
import * as sqliteVec from 'sqlite-vec';
import { pipeline } from '@huggingface/transformers';

const LIBRARY_DIR = path.dirname(new URL(import.meta.url).pathname);
const DB_PATH = path.join(LIBRARY_DIR, 'corpus.db');
const MODEL_CACHE = path.join(LIBRARY_DIR, 'model-cache');
const EMBEDDING_MODEL = 'Xenova/all-MiniLM-L6-v2';
const EMBEDDING_DIM = 384;

// ── Argument parsing ────────────────────────────────────────────────────────

const args = process.argv.slice(2);
let topK = 5;
let verbose = false;
let categoryFilter = null;
let originFilter = null;
let authorFilter = null;
let dateFilter = null;
let tagsFilter = null;
let sectionFilter = null;
const queryParts = [];

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--top' && args[i + 1]) {
    topK = parseInt(args[i + 1], 10);
    i++;
  } else if (args[i] === '--verbose') {
    verbose = true;
  } else if (args[i] === '--category' && args[i + 1]) {
    categoryFilter = args[i + 1];
    i++;
  } else if (args[i] === '--origin' && args[i + 1]) {
    originFilter = args[i + 1];
    i++;
  } else if (args[i] === '--author' && args[i + 1]) {
    authorFilter = args[i + 1];
    i++;
  } else if (args[i] === '--date' && args[i + 1]) {
    dateFilter = args[i + 1];
    i++;
  } else if (args[i] === '--tags' && args[i + 1]) {
    tagsFilter = args[i + 1];
    i++;
  } else if (args[i] === '--section' && args[i + 1]) {
    sectionFilter = args[i + 1];
    i++;
  } else {
    queryParts.push(args[i]);
  }
}

const query = queryParts.join(' ').trim();

if (!query) {
  console.error(`Usage: node search.mjs [options] "your query"

Options:
  --top N                  Number of results (default: 5)
  --category <cat>         Filter: lesson, decision, contact, transcript, analysis, backstory, journal, archive, misc (comma-separate for multiple)
  --origin <channel>       Filter by source channel (e.g. slack_main, slack_meetos)
  --author <name>          Filter by author/speaker (partial match)
  --date <date>            Filter by content date (YYYY-MM or YYYY-MM-DD prefix match)
  --tags <tag>             Filter by tag (partial match)
  --section <name>         Filter by section heading (partial match)
  --verbose                Output as structured JSON`);
  process.exit(1);
}

if (!fs.existsSync(DB_PATH)) {
  console.error('No library corpus found. The library has not been seeded yet.');
  process.exit(1);
}

// ── Main ────────────────────────────────────────────────────────────────────

async function main() {
  const embed = await pipeline('feature-extraction', EMBEDDING_MODEL, {
    cache_dir: MODEL_CACHE,
    quantized: true,
  });

  const output = await embed(query, { pooling: 'mean', normalize: true });
  const queryVec = Array.from(output.data).slice(0, EMBEDDING_DIM);
  const queryBuf = Buffer.from(new Float32Array(queryVec).buffer);

  const db = new Database(DB_PATH, { readonly: true });
  sqliteVec.load(db);

  const hasFilters = categoryFilter || originFilter || authorFilter || dateFilter || tagsFilter || sectionFilter;
  const fetchK = hasFilters ? topK * 5 : topK;

  const candidates = db.prepare(`
    SELECT
      v.id,
      v.distance,
      c.source,
      c.category,
      c.section,
      c.chunk_index,
      c.text,
      c.origin_channel,
      c.author,
      c.content_date,
      c.tags,
      c.ingested_at
    FROM chunk_vectors v
    JOIN chunks c ON c.id = v.id
    WHERE embedding MATCH ?
      AND k = ?
    ORDER BY distance
  `).all(queryBuf, fetchK);

  db.close();

  // Apply filters
  let results = candidates;

  if (categoryFilter) {
    const cats = categoryFilter.split(',').map(c => c.trim().toLowerCase());
    results = results.filter(r => cats.includes(r.category));
  }

  if (originFilter) {
    const needle = originFilter.toLowerCase();
    results = results.filter(r => r.origin_channel && r.origin_channel.toLowerCase().includes(needle));
  }

  if (authorFilter) {
    const needle = authorFilter.toLowerCase();
    results = results.filter(r => r.author && r.author.toLowerCase().includes(needle));
  }

  if (dateFilter) {
    results = results.filter(r => r.content_date && r.content_date.startsWith(dateFilter));
  }

  if (tagsFilter) {
    const needle = tagsFilter.toLowerCase();
    results = results.filter(r => r.tags && r.tags.toLowerCase().includes(needle));
  }

  if (sectionFilter) {
    const needle = sectionFilter.toLowerCase();
    results = results.filter(r => r.section && r.section.toLowerCase().includes(needle));
  }

  results = results.slice(0, topK);

  if (results.length === 0) {
    console.log('No results found.');
    const filters = [];
    if (categoryFilter) filters.push(`category: ${categoryFilter}`);
    if (originFilter) filters.push(`origin: ${originFilter}`);
    if (authorFilter) filters.push(`author: ${authorFilter}`);
    if (dateFilter) filters.push(`date: ${dateFilter}`);
    if (tagsFilter) filters.push(`tags: ${tagsFilter}`);
    if (sectionFilter) filters.push(`section: ${sectionFilter}`);
    if (filters.length) console.log(`  (filters: ${filters.join(', ')})`);
    process.exit(0);
  }

  if (verbose) {
    const out = results.map(r => ({
      score: Math.round((1 - r.distance) * 100) / 100,
      source: r.source,
      category: r.category,
      section: r.section || null,
      origin_channel: r.origin_channel || null,
      author: r.author || null,
      content_date: r.content_date || null,
      tags: r.tags || null,
      text: r.text,
    }));
    console.log(JSON.stringify(out, null, 2));
  } else {
    for (let i = 0; i < results.length; i++) {
      const r = results[i];
      const score = Math.round((1 - r.distance) * 100);
      const meta = [];
      if (r.category) meta.push(r.category);
      if (r.origin_channel) meta.push(`from: ${r.origin_channel}`);
      if (r.author) meta.push(`author: ${r.author}`);
      if (r.content_date) meta.push(`date: ${r.content_date}`);
      if (r.section) meta.push(`section: ${r.section}`);
      if (r.tags) meta.push(`tags: ${r.tags}`);
      const metaStr = meta.length ? ` [${meta.join(' | ')}]` : '';

      console.log(`\n--- Result ${i + 1} (${score}% match) ---`);
      console.log(`Source: ${r.source}${metaStr}`);
      console.log(`\n${r.text}`);
    }
    console.log('');
  }
}

main().catch(err => {
  console.error('Search failed:', err);
  process.exit(1);
});
