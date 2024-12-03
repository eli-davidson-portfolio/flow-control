#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common utilities
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"

# Configuration
DB_DIR="$PROJECT_ROOT/data/db"
MAIN_DB="$DB_DIR/audit.db"

# Ensure database exists
ensure_db() {
    if [ ! -f "$MAIN_DB" ]; then
        log_warning "Database not found, running migrations..."
        "$SCRIPT_DIR/manage.sh" migrate
    fi
}

# Record directory
record_directory() {
    local path="$1"
    local type="$2"
    local description="$3"
    
    ensure_db
    
    sqlite3 "$MAIN_DB" <<EOF
INSERT OR REPLACE INTO directories (path, type, description, last_modified)
VALUES ('$path', '$type', '$description', datetime('now'));
EOF
}

# Record file
record_file() {
    local path="$1"
    local type="$2"
    local status="$3"
    
    ensure_db
    
    local dir_path=$(dirname "$path")
    
    sqlite3 "$MAIN_DB" <<EOF
WITH dir AS (
    SELECT id FROM directories WHERE path = '$dir_path'
)
INSERT OR REPLACE INTO files (directory_id, path, type, status, last_used)
VALUES (
    (SELECT id FROM dir),
    '$path',
    '$type',
    '$status',
    datetime('now')
);
EOF
}

# Record code metrics
record_metrics() {
    local path="$1"
    local loc="$2"
    local comments="$3"
    local complexity="$4"
    local functions="$5"
    local coverage="$6"
    
    ensure_db
    
    sqlite3 "$MAIN_DB" <<EOF
WITH file AS (
    SELECT id FROM files WHERE path = '$path'
)
INSERT INTO code_metrics (
    file_id, lines_of_code, comment_lines,
    complexity, function_count, test_coverage
)
VALUES (
    (SELECT id FROM file),
    $loc, $comments, $complexity,
    $functions, $coverage
);
EOF
}

# Record dependency
record_dependency() {
    local source="$1"
    local target="$2"
    local type="$3"
    
    ensure_db
    
    sqlite3 "$MAIN_DB" <<EOF
WITH source_file AS (
    SELECT id FROM files WHERE path = '$source'
),
target_file AS (
    SELECT id FROM files WHERE path = '$target'
)
INSERT OR REPLACE INTO dependencies (source_file_id, target_file_id, type)
VALUES (
    (SELECT id FROM source_file),
    (SELECT id FROM target_file),
    '$type'
);
EOF
}

# Record documentation status
record_documentation() {
    local path="$1"
    local has_readme="$2"
    local has_tests="$3"
    local has_docs="$4"
    
    ensure_db
    
    sqlite3 "$MAIN_DB" <<EOF
WITH file AS (
    SELECT id FROM files WHERE path = '$path'
)
INSERT OR REPLACE INTO documentation (
    file_id, has_readme, has_tests,
    has_docs, last_updated
)
VALUES (
    (SELECT id FROM file),
    $has_readme, $has_tests,
    $has_docs, datetime('now')
);
EOF
}

# Record audit log
record_audit_log() {
    local category="$1"
    local severity="$2"
    local message="$3"
    local details="$4"
    
    ensure_db
    
    sqlite3 "$MAIN_DB" <<EOF
INSERT INTO audit_logs (category, severity, message, details)
VALUES ('$category', '$severity', '$message', '$details');
EOF
}

# Record audit report
record_audit_report() {
    local type="$1"
    local format="$2"
    local content="$3"
    
    ensure_db
    
    sqlite3 "$MAIN_DB" <<EOF
INSERT INTO audit_reports (type, format, content)
VALUES ('$type', '$format', '$content');
EOF
}

# Get unused files
get_unused_files() {
    ensure_db
    
    sqlite3 "$MAIN_DB" <<EOF
SELECT path, type FROM files
WHERE status = 'unused'
ORDER BY path;
EOF
}

# Get high complexity files
get_high_complexity_files() {
    local threshold="${1:-15}"
    
    ensure_db
    
    sqlite3 "$MAIN_DB" <<EOF
SELECT f.path, m.complexity
FROM files f
JOIN code_metrics m ON f.id = m.file_id
WHERE m.complexity > $threshold
ORDER BY m.complexity DESC;
EOF
}

# Get low coverage files
get_low_coverage_files() {
    local threshold="${1:-70}"
    
    ensure_db
    
    sqlite3 "$MAIN_DB" <<EOF
SELECT f.path, m.test_coverage
FROM files f
JOIN code_metrics m ON f.id = m.file_id
WHERE m.test_coverage < $threshold
AND m.test_coverage > 0
ORDER BY m.test_coverage ASC;
EOF
}

# Get recent audit logs
get_recent_audit_logs() {
    local limit="${1:-10}"
    
    ensure_db
    
    sqlite3 "$MAIN_DB" <<EOF
SELECT datetime(created_at), category, severity, message
FROM audit_logs
ORDER BY created_at DESC
LIMIT $limit;
EOF
}

# Export functions
export -f record_directory
export -f record_file
export -f record_metrics
export -f record_dependency
export -f record_documentation
export -f record_audit_log
export -f record_audit_report
export -f get_unused_files
export -f get_high_complexity_files
export -f get_low_coverage_files
export -f get_recent_audit_logs 