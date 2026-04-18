#!/usr/bin/env node
// sqlite3 CLI shim using better-sqlite3
const Database = require('/workspace/group/node_modules/better-sqlite3');
const fs = require('fs');

const args = process.argv.slice(2);
if (args.length === 0) {
  console.error('Usage: sqlite3 <database> [sql | .command]');
  process.exit(1);
}

const dbPath = args[0];
const sqlArg = args.slice(1).join(' ').trim();

let sql = '';

if (sqlArg === '' || sqlArg.startsWith('-')) {
  sql = fs.readFileSync(0, 'utf8');
} else if (sqlArg === '.dump') {
  const db = new Database(dbPath);
  const tables = db.prepare("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name").all();

  console.log('BEGIN TRANSACTION;');
  for (const table of tables) {
    console.log(table.sql + ';');
    const rows = db.prepare(`SELECT * FROM "${table.name}"`).all();
    for (const row of rows) {
      const vals = Object.values(row).map(v => {
        if (v === null) return 'NULL';
        if (typeof v === 'number') return v;
        return "'" + String(v).replace(/'/g, "''") + "'";
      });
      console.log(`INSERT INTO "${table.name}" VALUES(${vals.join(',')});`);
    }
  }
  const ver = db.pragma('user_version', { simple: true });
  if (ver) console.log(`PRAGMA user_version=${ver};`);
  console.log('COMMIT;');
  db.close();
  process.exit(0);
} else {
  sql = sqlArg;
}

if (!sql.trim()) process.exit(0);

try {
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');

  const statements = sql.split(/;\s*/).filter(s => s.trim());

  for (const stmt of statements) {
    const trimmed = stmt.trim();
    if (!trimmed) continue;

    if (trimmed.toUpperCase().startsWith('PRAGMA')) {
      const match = trimmed.match(/^PRAGMA\s+(\w+)\s*=\s*(.+)$/i);
      if (match) {
        db.pragma(`${match[1]} = ${match[2]}`);
        continue;
      }
      const result = db.pragma(trimmed.replace(/^PRAGMA\s+/i, ''));
      if (result !== undefined && result !== null) {
        if (Array.isArray(result)) {
          result.forEach(r => console.log(Object.values(r).join('|')));
        } else {
          console.log(result);
        }
      }
      continue;
    }

    const upper = trimmed.toUpperCase();
    if (upper.startsWith('SELECT') || upper.startsWith('WITH') || upper.startsWith('EXPLAIN')) {
      const rows = db.prepare(trimmed).all();
      for (const row of rows) {
        console.log(Object.values(row).join('|'));
      }
    } else {
      db.exec(trimmed);
    }
  }

  db.close();
} catch (err) {
  console.error(err.message);
  process.exit(1);
}
