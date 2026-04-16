-- Multi-Project System Schema v4
-- Creates all tables for project management, task tracking,
-- memory persistence, agent lenses, and session logging.
PRAGMA user_version = 4;

CREATE TABLE IF NOT EXISTS projects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  status TEXT DEFAULT 'active' CHECK(status IN ('active','paused','archived')),
  description TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  last_session_at TEXT,
  pause_summary TEXT,
  working_context TEXT,
  required_lenses TEXT DEFAULT ''
);

CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES projects(id),
  date TEXT DEFAULT (datetime('now')),
  session_type TEXT DEFAULT 'mixed' CHECK(session_type IN ('strategy','development','review','mixed')),
  exchange_count INTEGER DEFAULT 0,
  summary TEXT,
  key_outputs TEXT
);
CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project_id);

CREATE TABLE IF NOT EXISTS specs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES projects(id),
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'draft' CHECK(status IN ('draft','active','done','archived')),
  priority INTEGER DEFAULT 2 CHECK(priority IN (1,2,3)),
  notes TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_specs_project ON specs(project_id, status);

CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY,
  project_id INTEGER NOT NULL,
  spec_id INTEGER,
  session_id INTEGER,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'open',
  priority TEXT DEFAULT 'next',
  file_path TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  done_at TEXT
);

CREATE TABLE IF NOT EXISTS memory (
  id INTEGER PRIMARY KEY,
  project_id INTEGER NOT NULL,
  type TEXT DEFAULT 'fact',
  content TEXT NOT NULL,
  importance INTEGER DEFAULT 2,
  always_load INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  last_write TEXT
);

CREATE TABLE IF NOT EXISTS decisions (
  id INTEGER PRIMARY KEY,
  project_id INTEGER NOT NULL,
  session_id INTEGER,
  date TEXT DEFAULT (datetime('now')),
  type TEXT,
  title TEXT NOT NULL,
  decision TEXT,
  rationale TEXT,
  status TEXT DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS documents (
  id INTEGER PRIMARY KEY,
  project_id INTEGER NOT NULL,
  path TEXT NOT NULL,
  type TEXT,
  title TEXT,
  description TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  UNIQUE(project_id, path)
);

CREATE TABLE IF NOT EXISTS agents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT UNIQUE NOT NULL,
  lens TEXT NOT NULL,
  prompt TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
