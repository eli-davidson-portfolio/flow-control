#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common utilities
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"

# Configuration
AUDIT_DB="$PROJECT_ROOT/data/audit.db"
DOCS_DIR="$PROJECT_ROOT/docs"
STRUCTURE_FILE="$DOCS_DIR/PROJECT_STRUCTURE.md"

# Initialize SQLite database
init_db() {
    sqlite3 "$AUDIT_DB" <<EOF
CREATE TABLE IF NOT EXISTS structure_violations (
    id INTEGER PRIMARY KEY,
    file_path TEXT,
    expected_location TEXT,
    current_location TEXT,
    violation_type TEXT,
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS documentation_status (
    id INTEGER PRIMARY KEY,
    file_path TEXT,
    last_updated TIMESTAMP,
    has_readme INTEGER,
    has_tests INTEGER,
    has_docs INTEGER
);

CREATE TABLE IF NOT EXISTS directory_stats (
    id INTEGER PRIMARY KEY,
    directory TEXT,
    file_count INTEGER,
    total_lines INTEGER,
    last_modified TIMESTAMP,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
}

# Check directory structure
check_structure() {
    log_header "Checking Project Structure"
    
    # Required directories from PROJECT_STRUCTURE.md
    declare -A required_dirs=(
        ["cmd"]="Main applications"
        ["internal"]="Private application code"
        ["pkg"]="Public library code"
        ["web"]="Web application code"
        ["docs"]="Documentation files"
        ["config"]="Configuration files"
        ["scripts"]="Development scripts"
        ["tests"]="Test files"
        ["build"]="Build artifacts"
        ["vendor"]="Dependencies"
    )
    
    # Check each required directory
    for dir in "${!required_dirs[@]}"; do
        if [ ! -d "$PROJECT_ROOT/$dir" ]; then
            log_error "Missing required directory: $dir (${required_dirs[$dir]})"
            sqlite3 "$AUDIT_DB" <<EOF
INSERT INTO structure_violations (file_path, violation_type)
VALUES ('$dir', 'missing_directory');
EOF
        fi
    done
    
    # Check for files in wrong locations
    find "$PROJECT_ROOT" -type f -not -path "*/\.*" | while read -r file; do
        rel_path=${file#$PROJECT_ROOT/}
        dir=$(dirname "$rel_path")
        
        case "$rel_path" in
            *.go)
                if [[ "$dir" != cmd/* ]] && [[ "$dir" != internal/* ]] && [[ "$dir" != pkg/* ]] && [[ "$dir" != tests/* ]]; then
                    log_warning "Go file in unexpected location: $rel_path"
                    sqlite3 "$AUDIT_DB" <<EOF
INSERT INTO structure_violations (file_path, violation_type)
VALUES ('$rel_path', 'wrong_location_go');
EOF
                fi
                ;;
            *.sh)
                if [[ "$dir" != scripts/* ]] && [[ "$dir" != tests/* ]]; then
                    log_warning "Shell script in unexpected location: $rel_path"
                    sqlite3 "$AUDIT_DB" <<EOF
INSERT INTO structure_violations (file_path, violation_type)
VALUES ('$rel_path', 'wrong_location_shell');
EOF
                fi
                ;;
            *.md)
                if [[ "$dir" != docs/* ]] && [[ "$rel_path" != "README.md" ]]; then
                    log_warning "Documentation file in unexpected location: $rel_path"
                    sqlite3 "$AUDIT_DB" <<EOF
INSERT INTO structure_violations (file_path, violation_type)
VALUES ('$rel_path', 'wrong_location_docs');
EOF
                fi
                ;;
        esac
    done
}

# Check documentation status
check_documentation() {
    log_header "Checking Documentation Status"
    
    find "$PROJECT_ROOT" -type d -not -path "*/\.*" -not -path "*/vendor/*" | while read -r dir; do
        rel_dir=${dir#$PROJECT_ROOT/}
        has_readme=0
        has_tests=0
        has_docs=0
        
        # Check for README
        if [ -f "$dir/README.md" ]; then
            has_readme=1
        fi
        
        # Check for tests
        if find "$dir" -maxdepth 1 -name "*_test.go" -o -name "*_test.sh" | grep -q .; then
            has_tests=1
        fi
        
        # Check for docs
        if [ -d "$dir/docs" ] || find "$dir" -maxdepth 1 -name "*.md" | grep -q -v "README.md"; then
            has_docs=1
        fi
        
        sqlite3 "$AUDIT_DB" <<EOF
INSERT OR REPLACE INTO documentation_status (
    file_path, last_updated, has_readme, has_tests, has_docs
) VALUES (
    '$rel_dir',
    (SELECT MAX(last_modified) FROM (
        SELECT DATETIME(MAX(strftime('%s', CURRENT_TIMESTAMP))) as last_modified 
        FROM documentation_status WHERE file_path = '$rel_dir'
    )),
    $has_readme, $has_tests, $has_docs
);
EOF
    done
}

# Track directory statistics
track_directory_stats() {
    log_header "Tracking Directory Statistics"
    
    find "$PROJECT_ROOT" -type d -not -path "*/\.*" -not -path "*/vendor/*" | while read -r dir; do
        rel_dir=${dir#$PROJECT_ROOT/}
        file_count=$(find "$dir" -maxdepth 1 -type f | wc -l)
        total_lines=$(find "$dir" -maxdepth 1 -type f -exec wc -l {} \; | awk '{sum += $1} END {print sum}')
        last_modified=$(find "$dir" -maxdepth 1 -type f -exec stat -f "%m" {} \; | sort -nr | head -n1)
        
        sqlite3 "$AUDIT_DB" <<EOF
INSERT INTO directory_stats (
    directory, file_count, total_lines, last_modified
) VALUES (
    '$rel_dir', $file_count, $total_lines, datetime($last_modified, 'unixepoch')
);
EOF
    done
}

# Generate audit report
generate_report() {
    log_header "Generating Audit Report"
    
    local report="$DOCS_DIR/AUDIT_REPORT.md"
    
    cat > "$report" <<EOF
# Project Audit Report
Generated on: $(date)

## Structure Violations
\`\`\`
$(sqlite3 "$AUDIT_DB" "SELECT file_path, violation_type, datetime(detected_at) FROM structure_violations ORDER BY detected_at DESC LIMIT 10;")
\`\`\`

## Documentation Status
\`\`\`
$(sqlite3 "$AUDIT_DB" "SELECT file_path, has_readme, has_tests, has_docs FROM documentation_status WHERE has_readme = 0 OR has_tests = 0 OR has_docs = 0;")
\`\`\`

## Directory Statistics
\`\`\`
$(sqlite3 "$AUDIT_DB" "SELECT directory, file_count, total_lines, datetime(last_modified) FROM directory_stats ORDER BY last_modified DESC LIMIT 10;")
\`\`\`

## Recommendations
1. Fix structure violations listed above
2. Add missing documentation where indicated
3. Review directories with high file counts or line counts
4. Update outdated documentation
EOF

    log_success "Report generated: $report"
}

# Main execution
main() {
    log_header "Starting Project Structure Audit"
    
    # Create directories
    mkdir -p "$(dirname "$AUDIT_DB")"
    
    # Initialize database
    init_db
    
    # Run audit steps
    check_structure
    check_documentation
    track_directory_stats
    generate_report
    
    log_success "Project structure audit completed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 