#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test framework
source "$TEST_ROOT/framework.sh"

# Initialize test suite
log_info "Starting test suite"
log_info "Starting Level 3: Operation Tests"

# Run operation tests
log_header "Level 3: Operation Tests"

# Test basic operations
test_basic_operations() {
    # Test file operations
    local test_file="/tmp/flow-control-test-$(date +%s)"
    echo "test" > "$test_file"
    [[ -f "$test_file" ]] && rm "$test_file"
}
export -f test_basic_operations

# Run tests
run_test_case "basic_operations" "test_basic_operations"

# Show summary
show_test_summary 