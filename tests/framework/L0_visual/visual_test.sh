#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test framework
source "$TEST_ROOT/framework.sh"

# Initialize test suite
log_info "Starting test suite"
log_info "Starting Level 0: Visual and Framework Tests"

# Run visual tests
log_header "Level 0: Visual and Framework Tests"

# Test progress indicators
test_progress_indicators() {
    show_progress 0 100 "Testing"
    sleep 0.1
    show_progress 50 100 "Testing"
    sleep 0.1
    show_progress 100 100 "Testing"
    return 0
}
export -f test_progress_indicators

# Test color output
test_color_output() {
    log_debug "Debug message"
    log_info "Info message"
    log_warning "Warning message"
    log_error "Error message"
    log_success "Success message"
    return 0
}
export -f test_color_output

# Run tests
run_test_case "progress_indicators" "test_progress_indicators"
run_test_case "color_output" "test_color_output"

# Show summary
show_test_summary