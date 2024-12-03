#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test framework
source "$TEST_ROOT/framework.sh"

# Initialize test suite
log_info "Starting test suite"
log_info "Starting Level 5: State Tests"

# Run state tests
log_header "Level 5: State Tests"

# Test basic state
test_basic_state() {
    # Test basic state functionality
    local test_file="/tmp/flow-control-test-$(date +%s)"
    echo "test" > "$test_file"
    [[ -f "$test_file" ]] && rm "$test_file"
}
export -f test_basic_state

# Run tests
run_test_case "basic_state" "test_basic_state"

# Show summary
show_test_summary 