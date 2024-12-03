#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test framework
source "$TEST_ROOT/framework.sh"

# Initialize test suite
log_info "Starting test suite"
log_info "Starting Level 1: Platform Tests"

# Run platform tests
log_header "Level 1: Platform Tests"

# Test OS detection
test_os_detection() {
    detect_os
    [[ -n "$OS" ]]
}
export -f test_os_detection

# Test shell detection
test_shell_detection() {
    detect_shell
    [[ -n "$SHELL_TYPE" ]]
}
export -f test_shell_detection

# Test Docker detection
test_docker_detection() {
    detect_docker
    [[ -n "$DOCKER_AVAILABLE" ]]
}
export -f test_docker_detection

# Run tests
run_test_case "os_detection" "test_os_detection"
run_test_case "shell_detection" "test_shell_detection"
run_test_case "docker_detection" "test_docker_detection"

# Show summary
show_test_summary 