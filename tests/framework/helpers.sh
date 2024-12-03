#!/usr/bin/env bash

# Source configuration
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Test framework helper functions

# Check if a test level is valid
is_valid_test_level() {
    local level=$1
    [[ -n "${TEST_LEVELS[$level]}" ]]
}

# Check if all required dependencies are installed
check_dependencies() {
    local level=$1
    local deps="${TEST_DEPENDENCIES[$level]}"
    local missing=()

    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies for $level: ${missing[*]}"
        return 1
    fi
    return 0
}

# Run tests with timeout
run_with_timeout() {
    local level=$1
    local cmd=$2
    local timeout="${TEST_TIMEOUTS[$level]}"

    if [ -z "$timeout" ]; then
        timeout=60
    fi

    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout" bash -c "$cmd"
    else
        # Fallback for systems without timeout command
        "$cmd" & pid=$!
        (sleep "$timeout" && kill -9 $pid) 2>/dev/null & watcher=$!
        wait $pid 2>/dev/null
        ret=$?
        pkill -P $watcher
        wait $watcher
        return $ret
    fi
}

# Setup test environment
setup_test_env() {
    local level=$1
    
    mkdir -p "$TEST_DATA_DIR"
    mkdir -p "$TEST_LOG_DIR"
    
    if [ "$DEBUG" = "true" ]; then
        log_debug "Setting up test environment for $level"
        log_debug "Test root: $TEST_ROOT_DIR"
        log_debug "Data dir: $TEST_DATA_DIR"
        log_debug "Log dir: $TEST_LOG_DIR"
    fi
}

# Cleanup test environment
cleanup_test_env() {
    local level=$1
    
    if [ "$DEBUG" = "true" ]; then
        log_debug "Cleaning up test environment for $level"
    fi
    
    # Add cleanup logic here
}

# Run a single test
run_test() {
    local level=$1
    local test_file=$2
    local test_name=$(basename "$test_file" .sh)
    
    log_step "Running test: $test_name"
    
    if [ "$VERBOSE" = "true" ]; then
        bash "$test_file"
    else
        bash "$test_file" >/dev/null
    fi
    
    local result=$?
    
    if [ $result -eq 0 ]; then
        log_success "Test passed: $test_name"
    else
        log_error "Test failed: $test_name"
        if [ "$FAIL_FAST" = "true" ]; then
            exit 1
        fi
    fi
    
    return $result
}

# Export functions
export -f is_valid_test_level
export -f check_dependencies
export -f run_with_timeout
export -f setup_test_env
export -f cleanup_test_env
export -f run_test 