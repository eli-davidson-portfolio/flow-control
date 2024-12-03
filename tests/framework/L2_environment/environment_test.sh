#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test framework
source "$TEST_ROOT/framework.sh"

# Initialize test suite
log_info "Starting test suite"
log_info "Starting Level 2: Environment Tests"

# Run environment tests
log_header "Level 2: Environment Tests"

# Test Docker availability
test_docker_availability() {
    detect_docker
    [[ "$DOCKER_AVAILABLE" -eq 1 ]]
}
export -f test_docker_availability

# Run tests
run_test_case "docker_availability" "test_docker_availability"

# Show summary
show_test_summary 