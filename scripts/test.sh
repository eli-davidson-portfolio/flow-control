#!/bin/bash
# test.sh
#
# Purpose:
#   Runs the complete test suite for the Flow Control project.
#   Executes both Go tests in Docker containers and shell script tests.
#   Provides coverage reporting and various test configuration options.
#   Ensures consistent test environment and dependency management.
#
# Usage:
#   ./test.sh [options]
#
# Options:
#   --coverage      Generate test coverage report (default: false)
#   --race         Enable race detection for Go tests (default: false)
#   --integration  Run integration tests (default: false)
#   --verbose      Enable verbose test output (default: false)
#   --failfast     Stop on first test failure (default: false)
#
# Environment Variables:
#   TEST_FLAGS     Additional flags to pass to go test
#   TEST_TIMEOUT   Test timeout duration (default: 5m)
#   TEST_PATTERN   Pattern to match test files (default: "")
#
# Dependencies:
#   - Docker: For running Go tests
#   - kcov: For shell script coverage (if --coverage is used)
#   - bash: Shell interpreter (4.0+)
#
# Exit Codes:
#   0: All tests passed
#   1: Test execution failed
#   2: Environment setup failed

set -e

# Source common functions and variables
source "$(dirname "$0")/common/init.sh"
source "$(dirname "$0")/lib/core/test.sh"

# Configure test flags based on command line arguments
#
# Processes command line arguments and sets up test configuration.
# See configure_test_flags in lib/core/test.sh for details.
configure_test_flags "$@"

# Run Go tests in Docker environment
#
# Executes Go tests within a Docker container for consistent environment.
# Handles test flags, timeouts, and patterns.
# See run_tests_in_docker in lib/core/test.sh for details.
run_tests_in_docker "$TEST_FLAGS" "$TEST_PATTERN" "$TEST_TIMEOUT"

# Run shell script tests with optional coverage
if [[ "$COVERAGE_ENABLED" == "true" ]]; then
    log_info "Running shell script tests with coverage..."
    if ! "$(dirname "$0")/tests/coverage/coverage.sh"; then
        log_error "Shell script tests failed"
        exit 1
    fi
else
    log_info "Running shell script tests..."
    for test_type in unit integration workflows; do
        log_info "Running $test_type tests..."
        while IFS= read -r -d '' test_file; do
            log_info "Running test: $test_file"
            if ! bash "$test_file"; then
                log_error "Test failed: $test_file"
                exit 1
            fi
        done < <(find "$(dirname "$0")/tests/$test_type" -name '*_test.sh' -print0)
    done
fi

# Generate coverage report if enabled
#
# Creates a combined coverage report for both Go and shell script tests.
# Only runs if --coverage flag is provided.
if [[ "$COVERAGE_ENABLED" == "true" ]]; then
    generate_coverage_report
fi