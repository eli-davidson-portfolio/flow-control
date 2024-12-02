#!/bin/bash
# test.sh
#
# Purpose:
#   Runs the test suite for the Flow Control project with configurable options.
#   All tests are run in Docker containers - local execution is not supported.
#   Automatically runs go mod tidy before tests to ensure dependency consistency.
#
# Usage:
#   ./test.sh [options]
#
# Options:
#   --coverage      Generate test coverage report (default: false)
#   --race         Enable race detection (default: false)
#   --integration  Run integration tests (default: false)
#   --verbose      Enable verbose test output (default: false)
#   --failfast     Stop on first test failure (default: false)
#
# Environment Variables:
#   TEST_FLAGS     Additional flags to pass to go test
#   TEST_TIMEOUT   Test timeout duration (default: 5m)
#   TEST_PATTERN   Pattern to match test files (default: "")

set -e

# Source common functions and variables
source "$(dirname "$0")/common/init.sh"

# Test configuration
TEST_TIMEOUT=${TEST_TIMEOUT:-"5m"}
TEST_FLAGS=${TEST_FLAGS:-""}
TEST_PATTERN=${TEST_PATTERN:-""}
COVERAGE_DIR="coverage"
COVERAGE_PROFILE="$COVERAGE_DIR/coverage.out"
COVERAGE_HTML="$COVERAGE_DIR/coverage.html"

# Parse command line arguments
COVERAGE_ENABLED=false
RACE_DETECTION=false
INTEGRATION_TESTS=false
VERBOSE_OUTPUT=false
FAIL_FAST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --coverage)
            COVERAGE_ENABLED=true
            shift
            ;;
        --race)
            RACE_DETECTION=true
            shift
            ;;
        --integration)
            INTEGRATION_TESTS=true
            shift
            ;;
        --verbose)
            VERBOSE_OUTPUT=true
            shift
            ;;
        --failfast)
            FAIL_FAST=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build test flags
if [[ "$COVERAGE_ENABLED" == "true" ]]; then
    mkdir -p "$COVERAGE_DIR"
    TEST_FLAGS="$TEST_FLAGS -coverprofile=$COVERAGE_PROFILE"
fi

if [[ "$RACE_DETECTION" == "true" ]]; then
    TEST_FLAGS="$TEST_FLAGS -race"
fi

if [[ "$VERBOSE_OUTPUT" == "true" ]]; then
    TEST_FLAGS="$TEST_FLAGS -v"
fi

if [[ "$FAIL_FAST" == "true" ]]; then
    TEST_FLAGS="$TEST_FLAGS -failfast"
fi

# Set test pattern for integration tests
if [[ "$INTEGRATION_TESTS" == "true" ]]; then
    TEST_PATTERN="Integration"
fi

# Ensure Docker environment is ready
log_info "Ensuring Docker environment..."
if ! ./scripts/docker-check.sh --quiet; then
    log_error "Docker environment is not ready. If you see Go version mismatch errors, this is why."
    log_error "Please ensure Docker is running and try again."
    exit 1
fi

# Run go mod tidy in Docker first
log_info "Running go mod tidy in Docker..."
if ! docker-compose run --rm test go mod tidy; then
    log_error "Failed to run go mod tidy in Docker"
    exit 1
fi

# Verify go.mod and go.sum haven't changed
if ! git diff --exit-code go.mod go.sum; then
    log_error "go.mod or go.sum changed after running go mod tidy"
    log_error "Please commit these changes before running tests"
    exit 1
fi

# Run tests in Docker
log_info "Running tests in Docker..."
docker-compose run --rm test go test $TEST_FLAGS -timeout=$TEST_TIMEOUT ${TEST_PATTERN:+-run=$TEST_PATTERN} ./...

# Generate coverage report if enabled
if [[ "$COVERAGE_ENABLED" == "true" && -f "$COVERAGE_PROFILE" ]]; then
    log_info "Generating coverage report..."
    docker-compose run --rm test go tool cover -html="$COVERAGE_PROFILE" -o "$COVERAGE_HTML"
    
    # Print coverage summary
    coverage_pct=$(docker-compose run --rm test go tool cover -func="$COVERAGE_PROFILE" | grep total | awk '{print $3}')
    log_info "Total coverage: $coverage_pct"
    
    # Open coverage report in browser if not in CI
    if [[ -z "$CI" ]]; then
        case "$(uname)" in
            Darwin)
                open "$COVERAGE_HTML"
                ;;
            Linux)
                if command -v xdg-open &>/dev/null; then
                    xdg-open "$COVERAGE_HTML"
                fi
                ;;
        esac
    fi
fi