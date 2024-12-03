#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source framework configuration and helpers
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/helpers.sh"

# Run all tests for a specific level
run_level_tests() {
    local level=$1
    local level_dir="$PROJECT_ROOT/tests/$level"
    
    log_header "Running ${TEST_LEVELS[$level]} ($level)"
    
    # Run Go tests
    if [ -d "$level_dir/go" ]; then
        log_step "Running Go tests for $level"
        find "$level_dir/go" -name "*_test.go" -exec dirname {} \; | sort -u | while read -r pkg; do
            (cd "$pkg" && go test -v ./...)
        done
    fi
    
    # Run shell tests
    if [ -d "$level_dir/shell" ]; then
        log_step "Running shell tests for $level"
        find "$level_dir/shell" -name "*.sh" -type f | while read -r test; do
            run_test "$level" "$test"
        done
    fi
}

# Run framework unit tests
run_framework_tests() {
    log_header "Running Framework Unit Tests"
    
    local framework_test_dir="$PROJECT_ROOT/tests/framework/unit"
    if [ -d "$framework_test_dir" ]; then
        find "$framework_test_dir" -name "*_test.sh" -type f | while read -r test; do
            run_test "framework" "$test"
        done
    fi
}

# Main execution
main() {
    log_header "Starting Test Suite"
    
    # Setup test environment
    setup_test_env "all"
    
    # Run framework tests first
    run_framework_tests
    
    # Run each test level in order
    for level in "${!TEST_LEVELS[@]}"; do
        if is_valid_test_level "$level"; then
            if check_dependencies "$level"; then
                run_level_tests "$level"
            else
                log_warning "Skipping $level tests due to missing dependencies"
            fi
        fi
    done
    
    # Cleanup test environment
    cleanup_test_env "all"
    
    log_success "Test suite completed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 