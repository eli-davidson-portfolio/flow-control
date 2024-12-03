#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common utilities
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"

# Configuration
AUDIT_DB="$PROJECT_ROOT/data/audit.db"
THRESHOLD_COMPLEXITY=15
THRESHOLD_LINES=500
THRESHOLD_FUNCS=20

# Initialize SQLite database
init_db() {
    sqlite3 "$AUDIT_DB" <<EOF
CREATE TABLE IF NOT EXISTS code_metrics (
    id INTEGER PRIMARY KEY,
    file_path TEXT,
    lines_of_code INTEGER,
    comment_lines INTEGER,
    complexity INTEGER,
    function_count INTEGER,
    test_coverage REAL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS style_violations (
    id INTEGER PRIMARY KEY,
    file_path TEXT,
    line_number INTEGER,
    violation_type TEXT,
    message TEXT,
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dependency_metrics (
    id INTEGER PRIMARY KEY,
    package_path TEXT,
    direct_deps INTEGER,
    indirect_deps INTEGER,
    external_deps INTEGER,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
}

# Check Go code metrics
check_go_metrics() {
    log_header "Checking Go Code Metrics"
    
    find "$PROJECT_ROOT" -name "*.go" -not -path "*/vendor/*" | while read -r file; do
        rel_path=${file#$PROJECT_ROOT/}
        
        # Count lines
        total_lines=$(wc -l < "$file")
        comment_lines=$(grep -c "^[[:space:]]*\/\/" "$file")
        
        # Get complexity metrics using gocyclo if available
        complexity=0
        if command -v gocyclo >/dev/null 2>&1; then
            complexity=$(gocyclo "$file" | awk '{sum += $1} END {print sum}')
        fi
        
        # Count functions
        func_count=$(grep -c "^func" "$file")
        
        # Get test coverage if it's not a test file
        coverage=0
        if [[ ! "$file" =~ _test\.go$ ]]; then
            if [ -f "$PROJECT_ROOT/coverage.out" ]; then
                coverage=$(go tool cover -func="$PROJECT_ROOT/coverage.out" | grep "${rel_path}$" | awk '{print $NF}' | tr -d '%')
            fi
        fi
        
        sqlite3 "$AUDIT_DB" <<EOF
INSERT INTO code_metrics (
    file_path, lines_of_code, comment_lines, complexity, function_count, test_coverage
) VALUES (
    '$rel_path', $total_lines, $comment_lines, $complexity, $func_count, $coverage
);
EOF
        
        # Check for potential issues
        if [ $total_lines -gt $THRESHOLD_LINES ]; then
            log_warning "File too long: $rel_path ($total_lines lines)"
        fi
        
        if [ $complexity -gt $THRESHOLD_COMPLEXITY ]; then
            log_warning "High complexity: $rel_path (complexity: $complexity)"
        fi
        
        if [ $func_count -gt $THRESHOLD_FUNCS ]; then
            log_warning "Too many functions: $rel_path ($func_count functions)"
        fi
    done
}

# Check shell script quality
check_shell_quality() {
    log_header "Checking Shell Script Quality"
    
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_warning "shellcheck not found, skipping shell script analysis"
        return
    fi
    
    find "$PROJECT_ROOT" -name "*.sh" -not -path "*/vendor/*" | while read -r file; do
        rel_path=${file#$PROJECT_ROOT/}
        
        # Run shellcheck
        shellcheck "$file" | while IFS= read -r violation; do
            if [[ $violation =~ ^In[[:space:]](.*)[[:space:]]line[[:space:]]([0-9]+): ]]; then
                line_num="${BASH_REMATCH[2]}"
                message="${violation#*: }"
                
                sqlite3 "$AUDIT_DB" <<EOF
INSERT INTO style_violations (
    file_path, line_number, violation_type, message
) VALUES (
    '$rel_path', $line_num, 'shellcheck', '$message'
);
EOF
            fi
        done
    done
}

# Check dependency metrics
check_dependencies() {
    log_header "Checking Dependencies"
    
    # Go dependencies
    if [ -f "$PROJECT_ROOT/go.mod" ]; then
        while read -r pkg; do
            direct_deps=$(go list -f '{{len .Imports}}' "$pkg" 2>/dev/null || echo 0)
            indirect_deps=$(go list -f '{{len .DepsErrors}}' "$pkg" 2>/dev/null || echo 0)
            external_deps=$(go list -f '{{len .Deps}}' "$pkg" 2>/dev/null || echo 0)
            
            sqlite3 "$AUDIT_DB" <<EOF
INSERT INTO dependency_metrics (
    package_path, direct_deps, indirect_deps, external_deps
) VALUES (
    '$pkg', $direct_deps, $indirect_deps, $external_deps
);
EOF
            
            if [ $direct_deps -gt 20 ]; then
                log_warning "High direct dependencies in $pkg: $direct_deps"
            fi
        done < <(go list ./... 2>/dev/null)
    fi
}

# Generate quality report
generate_report() {
    log_header "Generating Quality Report"
    
    local report="$PROJECT_ROOT/docs/CODE_QUALITY.md"
    
    cat > "$report" <<EOF
# Code Quality Report
Generated on: $(date)

## High Complexity Files
\`\`\`
$(sqlite3 "$AUDIT_DB" "SELECT file_path, complexity FROM code_metrics WHERE complexity > $THRESHOLD_COMPLEXITY ORDER BY complexity DESC;")
\`\`\`

## Large Files
\`\`\`
$(sqlite3 "$AUDIT_DB" "SELECT file_path, lines_of_code FROM code_metrics WHERE lines_of_code > $THRESHOLD_LINES ORDER BY lines_of_code DESC;")
\`\`\`

## Low Test Coverage
\`\`\`
$(sqlite3 "$AUDIT_DB" "SELECT file_path, test_coverage FROM code_metrics WHERE test_coverage < 70 AND test_coverage > 0 ORDER BY test_coverage ASC;")
\`\`\`

## Style Violations
\`\`\`
$(sqlite3 "$AUDIT_DB" "SELECT file_path, violation_type, COUNT(*) as count FROM style_violations GROUP BY file_path, violation_type ORDER BY count DESC LIMIT 10;")
\`\`\`

## Dependency Metrics
\`\`\`
$(sqlite3 "$AUDIT_DB" "SELECT package_path, direct_deps, external_deps FROM dependency_metrics ORDER BY direct_deps DESC LIMIT 10;")
\`\`\`

## Recommendations
1. Refactor files with high complexity
2. Split large files into smaller modules
3. Increase test coverage where indicated
4. Address style violations
5. Review high dependency packages
EOF

    log_success "Report generated: $report"
}

# Main execution
main() {
    log_header "Starting Code Quality Audit"
    
    # Create directories
    mkdir -p "$(dirname "$AUDIT_DB")"
    
    # Initialize database
    init_db
    
    # Run audit steps
    check_go_metrics
    check_shell_quality
    check_dependencies
    generate_report
    
    log_success "Code quality audit completed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 