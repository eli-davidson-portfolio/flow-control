-- flows table
CREATE TABLE IF NOT EXISTS flows (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    version INTEGER NOT NULL,
    config TEXT NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- flow_versions table
CREATE TABLE IF NOT EXISTS flow_versions (
    flow_id TEXT NOT NULL,
    version INTEGER NOT NULL,
    code TEXT NOT NULL,
    metadata TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (flow_id, version),
    FOREIGN KEY (flow_id) REFERENCES flows(id)
);

-- runtime_state table
CREATE TABLE IF NOT EXISTS runtime_state (
    flow_id TEXT PRIMARY KEY,
    status TEXT NOT NULL,
    error TEXT,
    started_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metrics TEXT,
    node_states TEXT,
    FOREIGN KEY (flow_id) REFERENCES flows(id)
);

-- metrics table
CREATE TABLE IF NOT EXISTS metrics (
    flow_id TEXT NOT NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metric_type TEXT NOT NULL,
    value REAL NOT NULL,
    metadata TEXT,
    FOREIGN KEY (flow_id) REFERENCES flows(id)
);

-- logs table
CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    flow_id TEXT NOT NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    level TEXT NOT NULL,
    node_id TEXT,
    message TEXT NOT NULL,
    metadata TEXT,
    FOREIGN KEY (flow_id) REFERENCES flows(id)
); 