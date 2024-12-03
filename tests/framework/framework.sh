#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Source dependencies
source "$LIB_DIR/core/logging.sh"
source "$LIB_DIR/core/progress.sh"
source "$LIB_DIR/core/platform_state.sh"
source "$LIB_DIR/bridge/protocol.sh"

# Test configuration
TEST_CASE_TIMEOUT=${TEST_CASE_TIMEOUT:-60}
TEST_DEBUG=${TEST_DEBUG:-0}
TEST_LOG="${PWD}/logs/test.log"

# Create log directory
mkdir -p "$(dirname "$TEST_LOG")"

# Test state
declare -A TEST_RESULTS
declare -A TEST_COUNTS

# Initialize test framework
init_test_framework() {
    # Reset counters
    TEST_COUNTS[total]=0
    TEST_COUNTS[passed]=0
    TEST_COUNTS[failed]=0
    TEST_COUNTS[skipped]=0
}

# Run test case
run_test_case() {
    local name=$1
    local func=$2
    local timeout=${3:-$TEST_CASE_TIMEOUT}
    
    ((TEST_COUNTS[total]++))
    
    # Run test with timeout if available
    if command -v timeout >/dev/null 2>&1; then
        if timeout "$timeout" bash -c "$func" > >(tee -a "$TEST_LOG") 2>&1; then
            TEST_RESULTS[$name]="pass"
            ((TEST_COUNTS[passed]++))
            log_success "Test passed: $name"
            return 0
        else
            TEST_RESULTS[$name]="fail"
            ((TEST_COUNTS[failed]++))
            log_error "Test failed: $name"
            return 1
        fi
    else
        # Run without timeout
        if bash -c "$func" > >(tee -a "$TEST_LOG") 2>&1; then
            TEST_RESULTS[$name]="pass"
            ((TEST_COUNTS[passed]++))
            log_success "Test passed: $name"
            return 0
        else
            TEST_RESULTS[$name]="fail"
            ((TEST_COUNTS[failed]++))
            log_error "Test failed: $name"
            return 1
        fi
    fi
}

# Skip test case
skip_test_case() {
    local name=$1
    local reason=${2:-"No reason provided"}
    
    ((TEST_COUNTS[total]++))
    ((TEST_COUNTS[skipped]++))
    TEST_RESULTS[$name]="skip"
    
    log_warning "Test skipped: $name ($reason)"
}

# Show test summary
show_test_summary() {
    local total=${TEST_COUNTS[total]}
    local passed=${TEST_COUNTS[passed]}
    local failed=${TEST_COUNTS[failed]}
    local skipped=${TEST_COUNTS[skipped]}
    
    echo
    log_header "Test Summary"
    log_info "Total: $total"
    log_info "Passed: $passed"
    [ "$failed" -gt 0 ] && log_error "Failed: $failed" || log_info "Failed: $failed"
    [ "$skipped" -gt 0 ] && log_warning "Skipped: $skipped" || log_info "Skipped: $skipped"
    echo
    
    return $((failed > 0))
}

# Export test functions
export -f run_test_case
export -f skip_test_case
export -f show_test_summary
export -f log_debug
export -f log_info
export -f log_warning
export -f log_error
export -f log_success
export -f log_header
export -f show_progress

# Export platform functions
export -f detect_os
export -f detect_shell
export -f detect_docker
export -f validate_shell

# Initialize framework
init_test_framework