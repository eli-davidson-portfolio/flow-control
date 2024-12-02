#!/usr/bin/env bash

# Test utilities for bash scripts
# Provides a simple testing framework with describe/it blocks and assertions

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_FAILED=0
CURRENT_DESCRIBE=""
CURRENT_TEST=""

# Initialize test environment
init_tests() {
    TESTS_RUN=0
    TESTS_FAILED=0
    CURRENT_DESCRIBE=""
    CURRENT_TEST=""
}

# Describe block - groups related tests
describe() {
    CURRENT_DESCRIBE="$1"
    echo -e "\n${BLUE}$1${NC}"
}

# Individual test case
it() {
    CURRENT_TEST="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  - $1... "
}

# Test failure
fail() {
    local message="$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAILED${NC}"
    echo "    $message"
    return 1
}

# Test success
pass() {
    echo -e "${GREEN}PASSED${NC}"
}

# Assert equal
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected '$expected' but got '$actual'}"
    
    if [ "$expected" != "$actual" ]; then
        fail "$message"
        return 1
    fi
    return 0
}

# Assert not equal
assert_ne() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Expected value to not equal '$unexpected'}"
    
    if [ "$unexpected" = "$actual" ]; then
        fail "$message"
        return 1
    fi
    return 0
}

# Assert true
assert_true() {
    local actual="$1"
    local message="${2:-Expected true but got false}"
    
    if ! "$actual"; then
        fail "$message"
        return 1
    fi
    return 0
}

# Assert false
assert_false() {
    local actual="$1"
    local message="${2:-Expected false but got true}"
    
    if "$actual"; then
        fail "$message"
        return 1
    fi
    return 0
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-File '$file' does not exist}"
    
    if [ ! -f "$file" ]; then
        fail "$message"
        return 1
    fi
    return 0
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory '$dir' does not exist}"
    
    if [ ! -d "$dir" ]; then
        fail "$message"
        return 1
    fi
    return 0
}

# Assert command exists
assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command '$cmd' not found}"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fail "$message"
        return 1
    fi
    return 0
}

# Print test summary
print_summary() {
    echo -e "\nTest Summary:"
    echo "  Total tests: $TESTS_RUN"
    echo "  Failed tests: $TESTS_FAILED"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "  ${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "  ${RED}Some tests failed${NC}"
        return 1
    fi
}

# Export functions
export -f init_tests
export -f describe
export -f it
export -f fail
export -f pass
export -f assert_eq
export -f assert_ne
export -f assert_true
export -f assert_false
export -f assert_file_exists
export -f assert_dir_exists
export -f assert_command_exists
export -f print_summary

# Export variables
export RED
export GREEN
export BLUE
export NC
export TESTS_RUN
export TESTS_FAILED
export CURRENT_DESCRIBE
export CURRENT_TEST 