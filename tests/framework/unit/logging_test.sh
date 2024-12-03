#!/bin/bash

# Unit Tests for Logging Library
source "${SCRIPT_DIR}/test/framework.sh"
source "${SCRIPT_DIR}/lib/core/logging.sh"

# Test setup
setup() {
    # Create temporary log file
    TEST_LOG_FILE=$(mktemp)
    export LOG_FILE="$TEST_LOG_FILE"
    export LOG_LEVEL="INFO"
}

# Test teardown
teardown() {
    rm -f "$TEST_LOG_FILE"
    unset LOG_FILE LOG_LEVEL
}

# Test log level setting
test_set_log_level() {
    # Test valid log levels
    set_log_level "DEBUG"
    assert_equals "0" "$LOG_LEVEL_CURRENT" "Debug level should be 0"
    
    set_log_level "INFO"
    assert_equals "1" "$LOG_LEVEL_CURRENT" "Info level should be 1"
    
    set_log_level "WARN"
    assert_equals "2" "$LOG_LEVEL_CURRENT" "Warn level should be 2"
    
    set_log_level "ERROR"
    assert_equals "3" "$LOG_LEVEL_CURRENT" "Error level should be 3"
    
    # Test invalid log level
    set_log_level "INVALID"
    assert_equals "1" "$LOG_LEVEL_CURRENT" "Invalid level should default to INFO"
}

# Test debug logging
test_log_debug() {
    # Should log when level is DEBUG
    set_log_level "DEBUG"
    log_debug "Debug message"
    assert_true "[[ -s '$TEST_LOG_FILE' ]]" "Debug message should be logged at DEBUG level"
    
    # Should not log when level is higher
    set_log_level "INFO"
    : > "$TEST_LOG_FILE"
    log_debug "Debug message"
    assert_true "[[ ! -s '$TEST_LOG_FILE' ]]" "Debug message should not be logged at INFO level"
}

# Test info logging
test_log_info() {
    # Should log when level is INFO or lower
    set_log_level "INFO"
    log_info "Info message"
    assert_true "[[ -s '$TEST_LOG_FILE' ]]" "Info message should be logged at INFO level"
    
    set_log_level "DEBUG"
    : > "$TEST_LOG_FILE"
    log_info "Info message"
    assert_true "[[ -s '$TEST_LOG_FILE' ]]" "Info message should be logged at DEBUG level"
    
    # Should not log when level is higher
    set_log_level "ERROR"
    : > "$TEST_LOG_FILE"
    log_info "Info message"
    assert_true "[[ ! -s '$TEST_LOG_FILE' ]]" "Info message should not be logged at ERROR level"
}

# Test error logging
test_log_error() {
    # Should always log errors regardless of level
    for level in DEBUG INFO WARN ERROR; do
        set_log_level "$level"
        : > "$TEST_LOG_FILE"
        log_error "Error message"
        assert_true "[[ -s '$TEST_LOG_FILE' ]]" "Error message should be logged at $level level"
    done
}

# Test log formatting
test_log_formatting() {
    set_log_level "INFO"
    log_info "Test message"
    
    # Check timestamp format if enabled
    if [[ "$LOG_TIMESTAMP" == "true" ]]; then
        assert_true "grep -q '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' '$TEST_LOG_FILE'" "Log should contain timestamp"
    fi
    
    # Check log format
    assert_true "grep -q '\[INFO\].*Test message' '$TEST_LOG_FILE'" "Log should follow format specification"
}

# Test log file rotation
test_log_rotation() {
    # Fill log file
    for i in {1..1000}; do
        log_info "Test message $i"
    done
    
    # Check if rotation occurred
    assert_true "[[ -f '${TEST_LOG_FILE}.1' ]]" "Log file should be rotated"
}

# Run all tests
run_test_suite 