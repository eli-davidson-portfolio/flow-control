-- Initial schema for project audit database

-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- Project structure tracking
CREATE TABLE IF NOT EXISTS directories (
    id INTEGER PRIMARY KEY,
    path TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL,  -- 'source', 'config', 'test', etc.
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY,
    directory_id INTEGER,
    path TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL,  -- 'go', 'shell', 'doc', etc.
    status TEXT NOT NULL,  -- 'active', 'unused', 'deprecated'
    last_used TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (directory_id) REFERENCES directories(id)
);

-- Code metrics
CREATE TABLE IF NOT EXISTS code_metrics (
    id INTEGER PRIMARY KEY,
    file_id INTEGER,
    lines_of_code INTEGER,
    comment_lines INTEGER,
    complexity INTEGER,
    function_count INTEGER,
    test_coverage REAL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (file_id) REFERENCES files(id)
);

-- Dependencies
CREATE TABLE IF NOT EXISTS dependencies (
    id INTEGER PRIMARY KEY,
    source_file_id INTEGER,
    target_file_id INTEGER,
    type TEXT NOT NULL,  -- 'import', 'require', 'source'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (source_file_id) REFERENCES files(id),
    FOREIGN KEY (target_file_id) REFERENCES files(id)
);

-- Documentation tracking
CREATE TABLE IF NOT EXISTS documentation (
    id INTEGER PRIMARY KEY,
    file_id INTEGER,
    has_readme INTEGER DEFAULT 0,
    has_tests INTEGER DEFAULT 0,
    has_docs INTEGER DEFAULT 0,
    last_updated TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (file_id) REFERENCES files(id)
);

-- Audit logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id INTEGER PRIMARY KEY,
    category TEXT NOT NULL,  -- 'structure', 'quality', 'usage'
    severity TEXT NOT NULL,  -- 'info', 'warning', 'error'
    message TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit reports
CREATE TABLE IF NOT EXISTS audit_reports (
    id INTEGER PRIMARY KEY,
    type TEXT NOT NULL,  -- 'structure', 'quality', 'usage'
    format TEXT NOT NULL,  -- 'md', 'json', etc.
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Migration tracking
CREATE TABLE IF NOT EXISTS schema_migrations (
    id INTEGER PRIMARY KEY,
    version INTEGER NOT NULL,
    name TEXT NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert migration record
INSERT INTO schema_migrations (version, name) VALUES (1, 'initial_schema'); 