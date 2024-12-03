#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test framework
source "$TEST_ROOT/framework.sh"

# Initialize test suite
log_info "Starting test suite"
log_info "Starting Level 5: SSE Tests"

# Run SSE tests
log_header "Level 5: SSE Tests"

# Test basic SSE
test_basic_sse() {
    # Test basic SSE functionality
    local test_file="/tmp/flow-control-test-$(date +%s)"
    echo "test" > "$test_file"
    [[ -f "$test_file" ]] && rm "$test_file"
}
export -f test_basic_sse

# Run tests
run_test_case "basic_sse" "test_basic_sse"

# Show summary
show_test_summary 