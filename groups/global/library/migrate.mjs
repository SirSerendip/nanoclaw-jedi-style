#!/usr/bin/env node
/**
 * migrate.mjs — One-time migration of existing JOTF content into the shared library.
 *
 * Copies source files from slack_main memory and slack_meetos vectorstore
 * into the library's sources/ directory with appropriate frontmatter,
 * then runs ingest.mjs to index everything.
 *
 * Idempotent: skips files that already exist in the target. Use --force to overwrite.
 *
 * Usage:
 *   node migrate.mjs              # migrate new content only
 *   node migrate.mjs --force      # overwrite existing files
 *   node migrate.mjs --dry-run    # show what would be copied without doing it
 */

import fs from 'fs';
import path from 'path';
import { execFileSync } from 'child_process';

const LIBRARY_DIR = path.dirname(new URL(import.meta.url).pathname);
const SOURCES_DIR = path.join(LIBRARY_DIR, 'sources');
const PROJECT_ROOT = path.resolve(LIBRARY_DIR, '..', '..', '..');

const SLACK_MAIN = path.join(PROJECT_ROOT, 'groups', 'slack_main');
const SLACK_MEETOS = path.join(PROJECT_ROOT, 'groups', 'slack_meetos');

const args = process.argv.slice(2);
const force = args.includes('--force');
const dryRun = args.includes('--dry-run');

let copiedCount = 0;
let skippedCount = 0;

// ── Helpers ──────────────────────────────────────────────────────────────────

function addFrontmatter(content, meta) {
  // Don't double-add frontmatter
  if (content.trimStart().startsWith('---')) return content;

  const lines = ['---'];
  for (const [key, value] of Object.entries(meta)) {
    if (value) lines.push(`${key}: ${value}`);
  }
  lines.push('---');
  return lines.join('\n') + '\n\n' + content;
}

function copyToLibrary(srcPath, category, filename, meta) {
  const destDir = path.join(SOURCES_DIR, category);
  const destPath = path.join(destDir, filename);

  if (!force && fs.existsSync(destPath)) {
    console.log(`  Skipping (exists): ${category}/${filename}`);
    skippedCount++;
    return;
  }

  if (dryRun) {
    console.log(`  Would copy: ${srcPath} → ${category}/${filename}`);
    copiedCount++;
    return;
  }

  fs.mkdirSync(destDir, { recursive: true });
  let content = fs.readFileSync(srcPath, 'utf-8');
  content = addFrontmatter(content, meta);
  fs.writeFileSync(destPath, content, 'utf-8');
  console.log(`  Copied: ${category}/${filename}`);
  copiedCount++;
}

function copyRawContent(content, category, filename, meta) {
  const destDir = path.join(SOURCES_DIR, category);
  const destPath = path.join(destDir, filename);

  if (!force && fs.existsSync(destPath)) {
    console.log(`  Skipping (exists): ${category}/${filename}`);
    skippedCount++;
    return;
  }

  if (dryRun) {
    console.log(`  Would write: ${category}/${filename}`);
    copiedCount++;
    return;
  }

  fs.mkdirSync(destDir, { recursive: true });
  content = addFrontmatter(content, meta);
  fs.writeFileSync(destPath, content, 'utf-8');
  console.log(`  Wrote: ${category}/${filename}`);
  copiedCount++;
}

// ── Migration sources ───────────────────────────────────────────────────────

function migrateSlackMainHot() {
  console.log('\n── slack_main hot memory ──');
  const hotDir = path.join(SLACK_MAIN, 'memory', 'hot');

  const hotFiles = {
    'lessons.md': 'lessons',
    'decisions.md': 'decisions',
    'contacts.md': 'contacts',
  };

  for (const [file, category] of Object.entries(hotFiles)) {
    const src = path.join(hotDir, file);
    if (fs.existsSync(src)) {
      copyToLibrary(src, category, file, { origin_channel: 'slack_main' });
    } else {
      console.log(`  Not found: ${src}`);
    }
  }
}

function migrateSlackMainWarm() {
  console.log('\n── slack_main warm memory ──');
  const warmDir = path.join(SLACK_MAIN, 'memory', 'warm');

  // Founders backstory
  const backstoryPath = path.join(warmDir, 'founders-backstory.md');
  if (fs.existsSync(backstoryPath)) {
    copyToLibrary(backstoryPath, 'backstories', 'founders-backstory.md', {
      origin_channel: 'slack_main',
    });
  }

  // Journal
  const journalPath = path.join(warmDir, 'journal.md');
  if (fs.existsSync(journalPath)) {
    copyToLibrary(journalPath, 'journal', 'slack-main-journal.md', {
      origin_channel: 'slack_main',
    });
  }

  // Skip status.md — ephemeral project tracking, not library material
}

function migrateSlackMainArchive() {
  console.log('\n── slack_main archive ──');
  const archiveDir = path.join(SLACK_MAIN, 'memory', 'archive');

  if (!fs.existsSync(archiveDir)) {
    console.log('  No archive directory found');
    return;
  }

  for (const file of fs.readdirSync(archiveDir)) {
    if (!file.endsWith('.md')) continue;
    const src = path.join(archiveDir, file);
    copyToLibrary(src, 'archive', file, { origin_channel: 'slack_main' });
  }
}

function migrateMeetosTranscripts() {
  console.log('\n── slack_meetos transcripts ──');
  const srcDir = path.join(SLACK_MEETOS, 'vectorstore', 'sources', 'transcripts');

  if (!fs.existsSync(srcDir)) {
    console.log('  No transcripts directory found');
    return;
  }

  for (const file of fs.readdirSync(srcDir)) {
    if (!file.endsWith('.md')) continue;
    const src = path.join(srcDir, file);
    const dateMatch = file.match(/^(\d{4}-\d{2}-\d{2})/);
    copyToLibrary(src, 'transcripts', file, {
      origin_channel: 'slack_meetos',
      contentDate: dateMatch ? dateMatch[1] : undefined,
    });
  }
}

function migrateMeetosAnalyses() {
  console.log('\n── slack_meetos analyses ──');
  const srcDir = path.join(SLACK_MEETOS, 'vectorstore', 'sources', 'analyses');

  if (!fs.existsSync(srcDir)) {
    console.log('  No analyses directory found');
    return;
  }

  for (const file of fs.readdirSync(srcDir)) {
    if (!file.endsWith('.md')) continue;
    const src = path.join(srcDir, file);
    const dateMatch = file.match(/^(\d{4}-\d{2}-\d{2})/);
    copyToLibrary(src, 'analyses', file, {
      origin_channel: 'slack_meetos',
      contentDate: dateMatch ? dateMatch[1] : undefined,
    });
  }
}

// ── Main ────────────────────────────────────────────────────────────────────

function main() {
  console.log('JOTF Shared Library — Migration');
  console.log(`Library: ${LIBRARY_DIR}`);
  console.log(`Mode: ${dryRun ? 'DRY RUN' : force ? 'FORCE (overwrite)' : 'normal (skip existing)'}`);

  migrateSlackMainHot();
  migrateSlackMainWarm();
  migrateSlackMainArchive();
  migrateMeetosTranscripts();
  migrateMeetosAnalyses();

  console.log(`\n── Summary ──`);
  console.log(`  ${dryRun ? 'Would copy' : 'Copied'}: ${copiedCount} files`);
  console.log(`  Skipped: ${skippedCount} files`);

  if (dryRun) {
    console.log('\nDry run complete. Run without --dry-run to execute.');
    return;
  }

  if (copiedCount === 0) {
    console.log('\nNo new files to ingest.');
    return;
  }

  console.log('\nRunning ingestion...');
  try {
    execFileSync('node', [path.join(LIBRARY_DIR, 'ingest.mjs')], {
      cwd: LIBRARY_DIR,
      stdio: 'inherit',
      timeout: 300_000,
    });
  } catch (err) {
    console.error('Ingestion failed:', err.message);
    process.exit(1);
  }

  console.log('\nMigration complete.');
}

main();
