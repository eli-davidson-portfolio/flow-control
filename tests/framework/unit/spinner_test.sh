#!/bin/bash

# Unit Tests for Progress and Spinner Library
source "${SCRIPT_DIR}/test/framework.sh"
source "${SCRIPT_DIR}/lib/core/spinner.sh"

# Test setup
setup() {
    # Create temporary output file for capturing spinner output
    TEST_OUTPUT_FILE=$(mktemp)
    export SPINNER_OUTPUT="$TEST_OUTPUT_FILE"
    # Disable actual terminal output during tests
    export SPINNER_TEST_MODE=true
}

# Test teardown
teardown() {
    rm -f "$TEST_OUTPUT_FILE"
    unset SPINNER_OUTPUT SPINNER_TEST_MODE
}

# Test spinner initialization
test_spinner_init() {
    # Test basic spinner
    start_spinner "Loading" "basic"
    assert_true "grep -q '|' '$TEST_OUTPUT_FILE'" "Basic spinner should use simple characters"
    stop_spinner 0
    
    # Test dots spinner
    start_spinner "Loading" "dots"
    assert_true "grep -q '⠋' '$TEST_OUTPUT_FILE'" "Dots spinner should use braille characters"
    stop_spinner 0
    
    # Test arrow spinner
    start_spinner "Loading" "arrow"
    assert_true "grep -q '←' '$TEST_OUTPUT_FILE'" "Arrow spinner should use arrow characters"
    stop_spinner 0
    
    # Test invalid style fallback
    start_spinner "Loading" "invalid"
    assert_true "grep -q '⠋' '$TEST_OUTPUT_FILE'" "Invalid style should fallback to dots"
    stop_spinner 0
}

# Test spinner message display
test_spinner_message() {
    start_spinner "Custom message"
    assert_true "grep -q 'Custom message' '$TEST_OUTPUT_FILE'" "Spinner should display custom message"
    stop_spinner 0
    
    # Test message update
    start_spinner "Initial message"
    update_spinner_message "Updated message"
    assert_true "grep -q 'Updated message' '$TEST_OUTPUT_FILE'" "Spinner should update message"
    stop_spinner 0
}

# Test spinner completion
test_spinner_completion() {
    # Test successful completion
    start_spinner "Working"
    stop_spinner 0 "Done"
    assert_true "grep -q '✓.*Done' '$TEST_OUTPUT_FILE'" "Spinner should show success symbol"
    
    # Test failure completion
    start_spinner "Working"
    stop_spinner 1 "Failed"
    assert_true "grep -q '✗.*Failed' '$TEST_OUTPUT_FILE'" "Spinner should show failure symbol"
}

# Test progress bar
test_progress_bar() {
    # Test 0% progress
    update_progress 0 "Starting"
    assert_true "grep -q '\[                    \].*0%' '$TEST_OUTPUT_FILE'" "Progress bar should be empty at 0%"
    
    # Test 50% progress
    update_progress 50 "Halfway"
    assert_true "grep -q '\[==========          \].*50%' '$TEST_OUTPUT_FILE'" "Progress bar should be half full at 50%"
    
    # Test 100% progress
    update_progress 100 "Complete"
    assert_true "grep -q '\[====================\].*100%' '$TEST_OUTPUT_FILE'" "Progress bar should be full at 100%"
}

# Test progress message updates
test_progress_message() {
    update_progress 0 "Initial message"
    assert_true "grep -q 'Initial message' '$TEST_OUTPUT_FILE'" "Progress should show initial message"
    
    update_progress 50 "Updated message"
    assert_true "grep -q 'Updated message' '$TEST_OUTPUT_FILE'" "Progress should show updated message"
}

# Test invalid progress values
test_invalid_progress() {
    # Test negative progress
    update_progress -10 "Invalid"
    assert_true "grep -q '\[                    \].*0%' '$TEST_OUTPUT_FILE'" "Negative progress should show as 0%"
    
    # Test progress > 100
    update_progress 110 "Invalid"
    assert_true "grep -q '\[====================\].*100%' '$TEST_OUTPUT_FILE'" "Progress > 100 should show as 100%"
}

# Test multi-line progress tracking
test_multi_line_progress() {
    # Start multiple progress indicators
    start_progress "Task 1" 1
    start_progress "Task 2" 2
    start_progress "Task 3" 3
    
    # Update progress for each task
    update_progress 50 "Task 1 halfway" 1
    update_progress 30 "Task 2 starting" 2
    update_progress 80 "Task 3 almost done" 3
    
    # Verify all progress bars are visible
    assert_true "grep -q 'Task 1.*50%' '$TEST_OUTPUT_FILE'" "Should show Task 1 progress"
    assert_true "grep -q 'Task 2.*30%' '$TEST_OUTPUT_FILE'" "Should show Task 2 progress"
    assert_true "grep -q 'Task 3.*80%' '$TEST_OUTPUT_FILE'" "Should show Task 3 progress"
}

# Run all tests
run_test_suite 