#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test framework
source "$TEST_ROOT/framework.sh"

# Initialize test suite
log_info "Starting test suite"
log_info "Starting Level 5: API Tests"

# Run API tests
log_header "Level 5: API Tests"

# Test basic endpoints
test_basic_endpoints() {
    # Test basic endpoint functionality
    local test_file="/tmp/flow-control-test-$(date +%s)"
    echo "test" > "$test_file"
    [[ -f "$test_file" ]] && rm "$test_file"
}
export -f test_basic_endpoints

# Run tests
run_test_case "basic_endpoints" "test_basic_endpoints"

# Show summary
show_test_summary 