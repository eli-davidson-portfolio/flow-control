-- Test state table
CREATE TABLE IF NOT EXISTS test_state (
    level INTEGER PRIMARY KEY,
    status INTEGER NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    timestamp TEXT NOT NULL
);

-- Test results table
CREATE TABLE IF NOT EXISTS test_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    test_name TEXT NOT NULL,
    status INTEGER NOT NULL,
    output TEXT NOT NULL,
    duration INTEGER NOT NULL,
    timestamp TEXT NOT NULL
);

-- Test logs table
CREATE TABLE IF NOT EXISTS test_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level INTEGER NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'info',
    timestamp TEXT NOT NULL
);

-- Drop existing indexes
DROP INDEX IF EXISTS idx_test_state_level;
DROP INDEX IF EXISTS idx_test_results_name;
DROP INDEX IF EXISTS idx_test_results_status;
DROP INDEX IF EXISTS idx_test_logs_level;
DROP INDEX IF EXISTS idx_test_logs_type;

-- Create indexes
CREATE INDEX idx_test_state_level ON test_state(level);
CREATE INDEX idx_test_results_name ON test_results(test_name);
CREATE INDEX idx_test_results_status ON test_results(status);
CREATE INDEX idx_test_logs_level ON test_logs(level);
CREATE INDEX idx_test_logs_type ON test_logs(type); 