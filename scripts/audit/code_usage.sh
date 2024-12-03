#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source dependencies
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"

# Configuration
DB_FILE="$PROJECT_ROOT/data/code_usage.db"
EXCLUDE_DIRS=("vendor" "tmp" "build" "coverage" "backups")
EXCLUDE_PATTERNS=("*_test.go" "*.test" "*.tmp" "*.bak" "*.log")

# Initialize database
init_db() {
    log_info "Initializing code usage database..."
    
    # Drop existing tables
    sqlite3 "$DB_FILE" "DROP TABLE IF EXISTS files; DROP TABLE IF EXISTS imports; DROP TABLE IF EXISTS packages;"
    
    # Create new tables
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE files (
    id INTEGER PRIMARY KEY,
    path TEXT UNIQUE,
    type TEXT,
    used INTEGER DEFAULT 0,
    last_modified DATETIME,
    used_by TEXT
);

CREATE TABLE imports (
    id INTEGER PRIMARY KEY,
    source_file TEXT,
    imported_package TEXT,
    UNIQUE(source_file, imported_package)
);

CREATE TABLE packages (
    id INTEGER PRIMARY KEY,
    package_path TEXT UNIQUE,
    used INTEGER DEFAULT 0,
    last_modified DATETIME
);

CREATE INDEX IF NOT EXISTS idx_files_path ON files(path);
CREATE INDEX IF NOT EXISTS idx_files_used ON files(used);
CREATE INDEX IF NOT EXISTS idx_imports_source ON imports(source_file);
CREATE INDEX IF NOT EXISTS idx_imports_package ON imports(imported_package);
CREATE INDEX IF NOT EXISTS idx_packages_path ON packages(package_path);
EOF
}

# Track Go package dependencies
track_go_dependencies() {
    local file="$1"
    log_info "Tracking dependencies for $file..."
    
    # Extract package imports
    local imports
    imports=$(go list -f '{{range .Imports}}{{.}} {{end}}' "$file" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$imports" ]; then
        for pkg in $imports; do
            sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO imports (source_file, imported_package)
VALUES ('$file', '$pkg');

INSERT OR REPLACE INTO packages (package_path, used, last_modified)
VALUES ('$pkg', 1, datetime('now'));
EOF
        done
    fi
}

# Track file usage
track_file() {
    local file="$1"
    local rel_path="${file#$PROJECT_ROOT/}"
    
    # Skip excluded files
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$file" == *"$pattern"* ]]; then
            return
        fi
    done
    
    # Skip excluded directories
    for dir in "${EXCLUDE_DIRS[@]}"; do
        if [[ "$file" == *"/$dir/"* ]]; then
            return
        fi
    done
    
    # Determine file type
    local type="unknown"
    case "$file" in
        *.go) type="go";;
        *.sh) type="shell";;
        *.sql) type="sql";;
        *.html) type="html";;
        *.css) type="css";;
        *.js) type="javascript";;
        *.md) type="markdown";;
        *.yml|*.yaml) type="yaml";;
        *.json) type="json";;
        Makefile|makefile) type="makefile";;
        Dockerfile) type="dockerfile";;
        *) type="other";;
    esac
    
    log_info "Tracking file: $rel_path ($type)"
    
    # Update file tracking
    sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO files (path, type, used, last_modified, used_by)
VALUES ('$rel_path', '$type', 1, datetime('now'), 'code_usage_audit');
EOF
    
    # Track Go dependencies if it's a Go file
    if [[ "$type" == "go" ]]; then
        track_go_dependencies "$file"
    fi
}

# Scan project files
scan_project() {
    log_info "Scanning project files..."
    
    # Find all files
    while IFS= read -r -d '' file; do
        track_file "$file"
    done < <(find "$PROJECT_ROOT" -type f -not -path "*/\.*" -print0)
    
    # Mark packages as used if they are imported
    sqlite3 "$DB_FILE" <<EOF
UPDATE packages SET used = 1
WHERE package_path IN (
    SELECT DISTINCT imported_package 
    FROM imports
);
EOF
}

# Generate report
generate_report() {
    log_info "Generating code usage report..."
    
    # Create report directory
    local report_dir="$PROJECT_ROOT/docs"
    mkdir -p "$report_dir"
    
    # Generate report
    {
        echo "# Code Usage Report"
        echo
        echo "## Overview"
        echo
        echo "This report shows the usage status of files in the project."
        echo
        echo "### Files by Type"
        echo
        sqlite3 "$DB_FILE" <<EOF
.mode markdown
SELECT 
    type as Type,
    COUNT(*) as Count,
    ROUND(AVG(used) * 100, 2) as "Usage %"
FROM files
GROUP BY type
ORDER BY Count DESC;
EOF
        
        echo
        echo "### Unused Files"
        echo
        sqlite3 "$DB_FILE" <<EOF
.mode markdown
SELECT 
    path as Path,
    type as Type,
    datetime(last_modified) as "Last Modified"
FROM files
WHERE used = 0
ORDER BY type, path;
EOF
        
        echo
        echo "### Package Dependencies"
        echo
        sqlite3 "$DB_FILE" <<EOF
.mode markdown
SELECT 
    i.imported_package as Package,
    COUNT(DISTINCT i.source_file) as "Import Count",
    GROUP_CONCAT(DISTINCT f.path) as "Used By"
FROM imports i
JOIN files f ON i.source_file = f.path
GROUP BY i.imported_package
ORDER BY "Import Count" DESC
LIMIT 20;
EOF
    } > "$report_dir/CODE_USAGE.md"
    
    log_success "Report generated: $report_dir/CODE_USAGE.md"
}

# Main execution
main() {
    log_header "Starting Code Usage Audit"
    
    # Initialize database
    init_db
    
    # Scan project
    scan_project
    
    # Generate report
    generate_report
    
    log_success "Code usage audit completed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 