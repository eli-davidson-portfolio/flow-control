#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test framework
source "$TEST_ROOT/framework.sh"

# Initialize test suite
log_info "Starting test suite"
log_info "Starting Level 5: Flow Tests"

# Run flow tests
log_header "Level 5: Flow Tests"

# Test basic flow
test_basic_flow() {
    # Test basic flow functionality
    local test_file="/tmp/flow-control-test-$(date +%s)"
    echo "test" > "$test_file"
    [[ -f "$test_file" ]] && rm "$test_file"
}
export -f test_basic_flow

# Run tests
run_test_case "basic_flow" "test_basic_flow"

# Show summary
show_test_summary 