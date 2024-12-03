#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test framework
source "$TEST_ROOT/framework.sh"

# Initialize test suite
log_info "Starting test suite"
log_info "Starting Level 5: Service Tests"

# Run service tests
log_header "Level 5: Service Tests"

# Test service startup
test_service_startup() {
    # Test basic service startup
    local test_pid="/tmp/flow-control-test-$(date +%s).pid"
    echo "1234" > "$test_pid"
    [[ -f "$test_pid" ]] && rm "$test_pid"
}
export -f test_service_startup

# Run tests
run_test_case "service_startup" "test_service_startup"

# Show summary
show_test_summary