#!/usr/bin/env node
/**
 * ingest.mjs — JOTF Shared Library ingestion pipeline.
 *
 * Indexes curated JOTF knowledge (lessons, decisions, contacts, transcripts,
 * analyses, backstories, journal entries, archives) into a unified vectorstore
 * with provenance tracking.
 *
 * Chunking adapts to content type:
 *   - lessons/decisions/contacts: split by H3 headings (natural units)
 *   - transcripts: speaker-turn-aware (~500 word windows)
 *   - analyses: MeetOS section-aware (decisions, actions, dynamics)
 *   - backstories: H3 person → H4 chapter sections
 *   - journal: each dated entry
 *   - general/misc: 500-word windows with 75-word overlap
 *
 * Usage:
 *   node ingest.mjs                  # ingest all new/changed files
 *   node ingest.mjs --force          # re-ingest everything
 *   node ingest.mjs --file <path>    # ingest a single file
 */

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import Database from 'better-sqlite3';
import * as sqliteVec from 'sqlite-vec';
import { pipeline } from '@huggingface/transformers';

const LIBRARY_DIR = path.dirname(new URL(import.meta.url).pathname);
const SOURCES_DIR = path.join(LIBRARY_DIR, 'sources');
const DB_PATH = path.join(LIBRARY_DIR, 'corpus.db');
const MODEL_CACHE = path.join(LIBRARY_DIR, 'model-cache');
const EMBEDDING_MODEL = 'Xenova/all-MiniLM-L6-v2';
const EMBEDDING_DIM = 384;

// Category mapping from directory names
const CATEGORY_MAP = {
  lessons: 'lesson',
  decisions: 'decision',
  contacts: 'contact',
  transcripts: 'transcript',
  analyses: 'analysis',
  backstories: 'backstory',
  journal: 'journal',
  archive: 'archive',
};

// ── Helpers ──────────────────────────────────────────────────────────────────

function fileHash(content) {
  return crypto.createHash('sha256').update(content).digest('hex');
}

function detectCategory(relPath) {
  const firstDir = relPath.split(path.sep)[0]?.toLowerCase();
  return CATEGORY_MAP[firstDir] || 'misc';
}

/**
 * Parse YAML-ish frontmatter from markdown content.
 * Returns { meta: {...}, body: "..." }
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*)$/);
  if (!match) return { meta: {}, body: content };

  const meta = {};
  for (const line of match[1].split('\n')) {
    const kv = line.match(/^(\w[\w_-]*):\s*(.+)/);
    if (kv) meta[kv[1].trim()] = kv[2].trim();
  }
  return { meta, body: match[2] };
}

/**
 * Extract date from filename (YYYY-MM-DD-slug.md) or frontmatter.
 */
function extractDate(filename, meta) {
  if (meta.contentDate || meta.content_date) return meta.contentDate || meta.content_date;
  const dateMatch = filename.match(/^(\d{4}-\d{2}-\d{2})/);
  return dateMatch ? dateMatch[1] : null;
}

// ── Heading-based chunking (lessons, decisions, contacts) ───────────────────

/**
 * Split by H3 headings. Each heading + its body becomes one chunk.
 * Used for lessons, decisions, contacts — naturally structured by H3.
 */
function chunkByH3(text, source, category, meta) {
  const chunks = [];
  const sections = text.split(/(?=^###\s)/m).filter(s => s.trim());

  for (const section of sections) {
    const headingMatch = section.match(/^###\s+(.+)/);
    const heading = headingMatch ? headingMatch[1].trim() : '';
    const body = headingMatch ? section.slice(headingMatch[0].length).trim() : section.trim();

    if (!body || body.length < 10) continue;

    // Extract date from heading if present (e.g., "### 2026-04-02 — Lesson Title")
    const headingDate = heading.match(/(\d{4}-\d{2}-\d{2})/);
    const contentDate = headingDate ? headingDate[1] : meta.contentDate || null;

    chunks.push({
      text: heading ? `[${heading}]\n${body}` : body,
      source,
      section: heading,
      index: chunks.length,
      author: meta.author || null,
      content_date: contentDate,
    });
  }

  // If no H3 headings found, fall back to simple chunking
  if (chunks.length === 0) {
    return chunkSimple(text, source, meta);
  }
  return chunks;
}

// ── Backstory chunking (H3 person → H4 chapters) ───────────────────────────

function chunkBackstory(text, source, meta) {
  const chunks = [];
  // Split by H3 (person-level headings)
  const persons = text.split(/(?=^###\s)/m).filter(s => s.trim());

  for (const personBlock of persons) {
    const personMatch = personBlock.match(/^###\s+(.+)/);
    const personName = personMatch ? personMatch[1].trim() : 'Unknown';
    const personBody = personMatch ? personBlock.slice(personMatch[0].length).trim() : personBlock.trim();

    // Split by H4 (chapter-level headings)
    const chapters = personBody.split(/(?=^####\s)/m).filter(s => s.trim());

    if (chapters.length <= 1) {
      // No chapters — chunk as one
      if (personBody.length > 50) {
        const subChunks = chunkLongText(personBody, source, personName, meta);
        chunks.push(...subChunks.map(c => ({
          ...c,
          author: personName,
        })));
      }
    } else {
      for (const chapter of chapters) {
        const chapterMatch = chapter.match(/^####\s+(.+)/);
        const chapterTitle = chapterMatch ? chapterMatch[1].trim() : '';
        const chapterBody = chapterMatch ? chapter.slice(chapterMatch[0].length).trim() : chapter.trim();

        if (!chapterBody || chapterBody.length < 30) continue;

        const sectionLabel = chapterTitle ? `${personName} > ${chapterTitle}` : personName;

        // Sub-chunk long chapters
        if (chapterBody.split(/\s+/).length > 600) {
          const subChunks = chunkLongText(chapterBody, source, sectionLabel, meta);
          chunks.push(...subChunks.map(c => ({
            ...c,
            author: personName,
          })));
        } else {
          chunks.push({
            text: `[${sectionLabel}]\n${chapterBody}`,
            source,
            section: sectionLabel,
            index: chunks.length,
            author: personName,
            content_date: meta.contentDate || null,
          });
        }
      }
    }
  }

  return chunks.length > 0 ? chunks : chunkSimple(text, source, meta);
}

// ── Journal chunking (by dated entry) ───────────────────────────────────────

function chunkJournal(text, source, meta) {
  const chunks = [];
  // Journal entries typically start with ## or ### followed by a date
  const entries = text.split(/(?=^#{2,3}\s+\d{4}-\d{2}-\d{2})/m).filter(s => s.trim());

  for (const entry of entries) {
    const headingMatch = entry.match(/^#{2,3}\s+(.+)/);
    const heading = headingMatch ? headingMatch[1].trim() : '';
    const body = headingMatch ? entry.slice(headingMatch[0].length).trim() : entry.trim();

    if (!body || body.length < 20) continue;

    const dateMatch = heading.match(/(\d{4}-\d{2}-\d{2})/);

    chunks.push({
      text: heading ? `[${heading}]\n${body}` : body,
      source,
      section: heading,
      index: chunks.length,
      author: meta.author || null,
      content_date: dateMatch ? dateMatch[1] : meta.contentDate || null,
    });
  }

  return chunks.length > 0 ? chunks : chunkSimple(text, source, meta);
}

// ── Transcript chunking (by speaker turns) ──────────────────────────────────

function chunkTranscript(text, source, meta) {
  const chunks = [];
  const lines = text.split('\n').filter(l => l.trim());

  // Parse speaker turns: [HH:MM:SS.mmm --> HH:MM:SS.mmm] **Speaker**: text
  const turns = [];
  for (const line of lines) {
    const match = line.match(
      /^\[(\d{2}:\d{2}:\d{2}\.\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}\.\d{3})\]\s*\*\*(.+?)\*\*:\s*(.+)/
    );
    if (match) {
      turns.push({ start: match[1], end: match[2], speaker: match[3], text: match[4].trim() });
    }
  }

  if (turns.length === 0) return chunkSimple(text, source, meta);

  // Merge adjacent turns from same speaker
  const merged = [{ ...turns[0] }];
  for (let i = 1; i < turns.length; i++) {
    const prev = merged[merged.length - 1];
    if (turns[i].speaker === prev.speaker) {
      prev.end = turns[i].end;
      prev.text += ' ' + turns[i].text;
    } else {
      merged.push({ ...turns[i] });
    }
  }

  // Group into ~500 word chunks preserving speaker boundaries
  let currentChunk = [];
  let currentWords = 0;

  const metaPrefix = [
    meta.contentDate ? `Meeting date: ${meta.contentDate}` : '',
    meta.participants ? `Participants: ${meta.participants}` : '',
  ].filter(Boolean).join('\n');

  const flushChunk = () => {
    if (currentChunk.length === 0) return;
    const chunkText = currentChunk.map(t => `[${t.start}] ${t.speaker}: ${t.text}`).join('\n');
    const speakers = [...new Set(currentChunk.map(t => t.speaker))];
    chunks.push({
      text: metaPrefix ? `${metaPrefix}\n\n${chunkText}` : chunkText,
      source,
      section: `${currentChunk[0].start} - ${currentChunk[currentChunk.length - 1].end}`,
      index: chunks.length,
      author: speakers.join(', '),
      content_date: meta.contentDate || null,
    });
    currentChunk = [];
    currentWords = 0;
  };

  for (const turn of merged) {
    const words = turn.text.split(/\s+/).length;
    if (currentWords + words > 500 && currentChunk.length > 0) flushChunk();
    currentChunk.push(turn);
    currentWords += words;
  }
  flushChunk();
  return chunks;
}

// ── Analysis chunking (MeetOS section-aware) ────────────────────────────────

function chunkAnalysis(text, source, meta) {
  const chunks = [];
  const metaPrefix = [
    meta.contentDate ? `Meeting date: ${meta.contentDate}` : '',
    meta.participants ? `Participants: ${meta.participants}` : '',
    meta.meetingType ? `Meeting type: ${meta.meetingType}` : '',
  ].filter(Boolean).join('\n');

  const sections = text.split(/(?=^#{2,3}\s)/m).filter(s => s.trim());

  for (const section of sections) {
    const headingMatch = section.match(/^(#{2,3})\s+(.+)/);
    if (!headingMatch) continue;

    const level = headingMatch[1].length;
    const heading = headingMatch[2].trim();
    const body = section.slice(headingMatch[0].length).trim();
    if (!body || body.length < 20) continue;

    const hasSubsections = /^###\s/m.test(body);
    if (level === 2 && hasSubsections) {
      const preSubContent = body.split(/^###\s/m)[0].trim();
      if (preSubContent && preSubContent.length > 50) {
        chunks.push({
          text: `${metaPrefix}\n\n[${heading}]\n${preSubContent}`,
          source,
          section: heading,
          index: chunks.length,
          author: null,
          content_date: meta.contentDate || null,
        });
      }
      continue;
    }

    // Action items table: each row as a chunk
    if (/action items/i.test(heading) && /\|.*\|.*\|/.test(body)) {
      const rows = body.split('\n').filter(
        l => l.startsWith('|') && !l.includes('---') && !/^\|\s*Action\s*\|/i.test(l)
      );
      for (const row of rows) {
        const cells = row.split('|').map(c => c.trim()).filter(Boolean);
        if (cells.length >= 2) {
          const actionText = `Action: ${cells[0]}\nOwner: ${cells[1] || 'unassigned'}\nDeadline: ${cells[2] || 'none'}\nDependencies: ${cells[3] || 'none'}\nConfidence: ${cells[4] || 'unknown'}`;
          chunks.push({
            text: `${metaPrefix}\n\n[Action Item]\n${actionText}`,
            source,
            section: 'Action Items',
            index: chunks.length,
            author: null,
            content_date: meta.contentDate || null,
          });
        }
      }
      continue;
    }

    // Regular section — sub-chunk if long
    const words = body.split(/\s+/);
    if (words.length <= 600) {
      chunks.push({
        text: `${metaPrefix}\n\n[${heading}]\n${body}`,
        source,
        section: heading,
        index: chunks.length,
        author: null,
        content_date: meta.contentDate || null,
      });
    } else {
      const subChunks = chunkLongText(body, source, heading, meta);
      chunks.push(...subChunks);
    }
  }

  return chunks;
}

// ── Long text sub-chunker (by paragraphs) ───────────────────────────────────

function chunkLongText(text, source, sectionLabel, meta) {
  const chunks = [];
  const paragraphs = text.split(/\n\s*\n/).filter(p => p.trim());
  let current = '';
  let currentWords = 0;

  for (const para of paragraphs) {
    const paraWords = para.split(/\s+/).length;
    if (currentWords + paraWords > 500 && current) {
      chunks.push({
        text: sectionLabel ? `[${sectionLabel}]\n${current.trim()}` : current.trim(),
        source,
        section: sectionLabel,
        index: chunks.length,
        author: meta.author || null,
        content_date: meta.contentDate || null,
      });
      current = para;
      currentWords = paraWords;
    } else {
      current += (current ? '\n\n' : '') + para;
      currentWords += paraWords;
    }
  }
  if (current.trim()) {
    chunks.push({
      text: sectionLabel ? `[${sectionLabel}]\n${current.trim()}` : current.trim(),
      source,
      section: sectionLabel,
      index: chunks.length,
      author: meta.author || null,
      content_date: meta.contentDate || null,
    });
  }
  return chunks;
}

// ── Simple fallback chunker (500 words, 75 overlap) ─────────────────────────

function chunkSimple(text, source, meta) {
  const words = text.split(/\s+/).filter(Boolean);
  if (words.length === 0) return [];

  const chunks = [];
  let start = 0;
  while (start < words.length) {
    const end = Math.min(start + 500, words.length);
    chunks.push({
      text: words.slice(start, end).join(' '),
      source,
      section: '',
      index: chunks.length,
      author: meta.author || null,
      content_date: meta.contentDate || null,
    });
    if (end >= words.length) break;
    start = end - 75;
  }
  return chunks;
}

// ── Content detection & dispatch ────────────────────────────────────────────

function isTranscript(text) {
  // Match timestamped speaker lines — either "**Speaker N**:" or "**Real Name**:"
  return /\[\d{2}:\d{2}:\d{2}\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3}\]\s*\*\*.+?\*\*:/.test(text);
}

function isAnalysis(text) {
  return /^#\s*Meeting Intelligence Report/m.test(text);
}

function chunkDocument(text, source, filename, category, meta) {
  // Category-specific chunking
  if (category === 'lesson' || category === 'decision' || category === 'contact') {
    console.log(`    ${category} — chunking by H3 headings`);
    return chunkByH3(text, source, category, meta);
  }

  if (category === 'backstory') {
    console.log(`    Backstory — chunking by person/chapter`);
    return chunkBackstory(text, source, meta);
  }

  if (category === 'journal') {
    console.log(`    Journal — chunking by dated entry`);
    return chunkJournal(text, source, meta);
  }

  // For transcript category, try speaker-turn chunking first
  if (category === 'transcript') {
    const transcriptChunks = chunkTranscript(text, source, meta);
    if (transcriptChunks.length > 0) {
      console.log(`    Transcript — chunking by speaker turns`);
      return transcriptChunks;
    }
    console.log(`    Transcript (no speaker turns detected) — using simple chunking`);
    return chunkSimple(text, source, meta);
  }

  // Auto-detect for analyses/misc
  if (isTranscript(text)) {
    console.log(`    Transcript detected — chunking by speaker turns`);
    return chunkTranscript(text, source, meta);
  }

  if (isAnalysis(text)) {
    console.log(`    MeetOS analysis detected — chunking by section`);
    return chunkAnalysis(text, source, meta);
  }

  console.log(`    General content — using simple chunking`);
  return chunkSimple(text, source, meta);
}

// ── Collect source files ────────────────────────────────────────────────────

function collectSourceFiles(dir) {
  const files = [];
  if (!fs.existsSync(dir)) return files;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...collectSourceFiles(full));
    } else if (/\.(md|txt|markdown)$/i.test(entry.name)) {
      files.push(full);
    }
  }
  return files;
}

// ── Database setup ──────────────────────────────────────────────────────────

function initDB() {
  const db = new Database(DB_PATH);
  sqliteVec.load(db);

  db.exec(`
    CREATE TABLE IF NOT EXISTS file_hashes (
      path TEXT PRIMARY KEY,
      hash TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS chunks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'misc',
      section TEXT,
      chunk_index INTEGER,
      text TEXT NOT NULL,
      origin_channel TEXT,
      author TEXT,
      content_date TEXT,
      tags TEXT,
      ingested_at TEXT NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_chunks_category ON chunks(category);
    CREATE INDEX IF NOT EXISTS idx_chunks_origin ON chunks(origin_channel);
    CREATE INDEX IF NOT EXISTS idx_chunks_author ON chunks(author);
    CREATE INDEX IF NOT EXISTS idx_chunks_date ON chunks(content_date);

    CREATE VIRTUAL TABLE IF NOT EXISTS chunk_vectors USING vec0(
      id INTEGER PRIMARY KEY,
      embedding FLOAT[${EMBEDDING_DIM}]
    );
  `);

  return db;
}

// ── Main ────────────────────────────────────────────────────────────────────

async function main() {
  const args = process.argv.slice(2);
  const force = args.includes('--force');
  const singleFileIdx = args.indexOf('--file');
  const singleFile = singleFileIdx !== -1 ? args[singleFileIdx + 1] : null;

  console.log('Loading embedding model (first run downloads ~80MB)...');
  const embed = await pipeline('feature-extraction', EMBEDDING_MODEL, {
    cache_dir: MODEL_CACHE,
    quantized: true,
  });

  const db = initDB();

  let files;
  if (singleFile) {
    const resolved = path.isAbsolute(singleFile)
      ? singleFile
      : path.resolve(LIBRARY_DIR, singleFile);
    files = [resolved];
  } else {
    files = collectSourceFiles(SOURCES_DIR);
  }

  if (files.length === 0) {
    console.log('No source files found in', SOURCES_DIR);
    console.log('Add .md files to sources/{category}/ directories.');
    process.exit(0);
  }

  const getHash = db.prepare('SELECT hash FROM file_hashes WHERE path = ?');
  const setHash = db.prepare('REPLACE INTO file_hashes (path, hash) VALUES (?, ?)');
  const insertChunk = db.prepare(
    `INSERT INTO chunks (source, category, section, chunk_index, text,
     origin_channel, author, content_date, tags, ingested_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  );
  const insertVector = db.prepare(
    'INSERT INTO chunk_vectors (id, embedding) VALUES (CAST(? AS INTEGER), ?)'
  );
  const deleteVectors = db.prepare(
    'DELETE FROM chunk_vectors WHERE id IN (SELECT id FROM chunks WHERE source = ?)'
  );
  const deleteChunks = db.prepare('DELETE FROM chunks WHERE source = ?');

  let totalChunks = 0;
  let filesProcessed = 0;

  for (const file of files) {
    const relPath = path.relative(SOURCES_DIR, file);
    const content = fs.readFileSync(file, 'utf-8');
    const hash = fileHash(content);

    if (!force) {
      const existing = getHash.get(relPath);
      if (existing && existing.hash === hash) {
        console.log(`  Skipping (unchanged): ${relPath}`);
        continue;
      }
    }

    const { meta, body } = parseFrontmatter(content);
    const category = detectCategory(relPath);
    const filename = path.basename(file);
    const contentDate = extractDate(filename, meta);
    const originChannel = meta.origin_channel || meta.originChannel || null;
    const author = meta.author || null;
    const tags = meta.tags || null;

    // Merge frontmatter into meta object for chunkers
    const chunkMeta = { contentDate, author, participants: meta.participants, meetingType: meta.meeting_type };

    console.log(`  Ingesting: ${relPath} [${category}]`);

    // Remove old data for this source
    deleteVectors.run(relPath);
    deleteChunks.run(relPath);

    const chunks = chunkDocument(body, relPath, filename, category, chunkMeta);
    const now = new Date().toISOString();

    for (const chunk of chunks) {
      const output = await embed(chunk.text, { pooling: 'mean', normalize: true });
      const vector = Array.from(output.data).slice(0, EMBEDDING_DIM);
      const vectorBuf = Buffer.from(new Float32Array(vector).buffer);

      const { lastInsertRowid } = insertChunk.run(
        chunk.source, category, chunk.section, chunk.index, chunk.text,
        originChannel, chunk.author || author, chunk.content_date || contentDate,
        tags, now
      );
      insertVector.run(Number(lastInsertRowid), vectorBuf);
    }

    setHash.run(relPath, hash);
    totalChunks += chunks.length;
    filesProcessed++;
  }

  const totalRows = db.prepare('SELECT COUNT(*) as count FROM chunks').get();
  const categories = db.prepare(
    'SELECT category, COUNT(*) as count FROM chunks GROUP BY category'
  ).all();
  console.log(`\nDone! Processed ${filesProcessed} file(s), ${totalChunks} new chunks.`);
  console.log(`Corpus total: ${totalRows.count} chunks indexed.`);
  console.log('By category:', categories.map(c => `${c.category}: ${c.count}`).join(', '));

  db.close();
}

main().catch(err => {
  console.error('Ingestion failed:', err);
  process.exit(1);
});
