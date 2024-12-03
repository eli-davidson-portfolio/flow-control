#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common utilities
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"

# Configuration
OLD_TEST_DIRS=(
    "$PROJECT_ROOT/test"
    "$PROJECT_ROOT/tests"
    "$PROJECT_ROOT/tests/integration"
    "$PROJECT_ROOT/tests/unit"
)

# Migrate Go tests
migrate_go_tests() {
    log_header "Migrating Go Tests"
    
    # Unit tests
    find "$PROJECT_ROOT" -name "*_test.go" -type f | while read -r test_file; do
        local pkg_dir=$(dirname "$test_file")
        local pkg_name=$(basename "$pkg_dir")
        
        # Determine test level based on package
        local test_level
        case "$pkg_name" in
            parser|lexer|ast)
                test_level="L1_core"
                ;;
            server|runtime)
                test_level="L3_operations"
                ;;
            *)
                test_level="L5_application"
                ;;
        esac
        
        # Create test directory if it doesn't exist
        mkdir -p "$PROJECT_ROOT/tests/$test_level/go/$pkg_name"
        
        # Copy test file
        cp "$test_file" "$PROJECT_ROOT/tests/$test_level/go/$pkg_name/"
        log_success "Migrated: $test_file -> $test_level/go/$pkg_name/"
    done
}

# Migrate shell tests
migrate_shell_tests() {
    log_header "Migrating Shell Tests"
    
    for dir in "${OLD_TEST_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -name "*.sh" -type f | while read -r test_file; do
                local test_name=$(basename "$test_file")
                local test_type
                
                # Determine test level based on content
                if grep -q "visual\|ui\|layout" "$test_file"; then
                    test_type="L0_visual"
                elif grep -q "platform\|system\|core" "$test_file"; then
                    test_type="L1_core"
                elif grep -q "environment\|config" "$test_file"; then
                    test_type="L2_environment"
                elif grep -q "operation\|workflow" "$test_file"; then
                    test_type="L3_operations"
                else
                    test_type="L5_application"
                fi
                
                # Create test directory
                mkdir -p "$PROJECT_ROOT/tests/$test_type/shell"
                
                # Copy and update test file
                cp "$test_file" "$PROJECT_ROOT/tests/$test_type/shell/"
                log_success "Migrated: $test_file -> $test_type/shell/"
            done
        fi
    done
}

# Update test references
update_references() {
    log_header "Updating Test References"
    
    # Update Makefile references
    if [ -f "$PROJECT_ROOT/Makefile" ]; then
        sed -i.bak 's|tests|tests|g' "$PROJECT_ROOT/Makefile"
        sed -i.bak 's|tests/|tests/|g' "$PROJECT_ROOT/Makefile"
        rm -f "$PROJECT_ROOT/Makefile.bak"
        log_success "Updated Makefile references"
    fi
    
    # Update shell script references
    find "$PROJECT_ROOT/scripts" -name "*.sh" -type f | while read -r script; do
        sed -i.bak 's|tests|tests|g' "$script"
        sed -i.bak 's|tests/|tests/|g' "$script"
        rm -f "$script.bak"
        log_success "Updated references in: $script"
    done
}

# Clean up old test files
cleanup_old_tests() {
    log_header "Cleaning Up Old Tests"
    
    for dir in "${OLD_TEST_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            log_success "Removed old test directory: $dir"
        fi
    done
}

# Main execution
main() {
    log_header "Starting Test Migration"
    
    # Create new test structure
    mkdir -p "$PROJECT_ROOT/tests/"{L0_visual,L1_core,L2_environment,L3_operations,L5_application}/{go,shell}
    
    # Run migration steps
    migrate_go_tests
    migrate_shell_tests
    update_references
    cleanup_old_tests
    
    log_success "Test migration completed"
    log_info "Please review the migrated tests and update any remaining references"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 