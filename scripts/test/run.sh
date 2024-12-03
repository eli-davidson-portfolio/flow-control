#!/usr/bin/env bash

# Ensure we're running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash" >&2
    exit 1
fi

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/init.sh"
source "${SCRIPT_DIR}/../lib/progress/progress.sh"

# Test configuration
TEST_TIMEOUT="${TEST_TIMEOUT:-5m}"
TEST_FLAGS="${TEST_FLAGS:--v -race -cover}"
TEST_DIRS="${TEST_DIRS:-./...}"
LOG_DIR="logs/test-$(date +%Y%m%d_%H%M%S)"

# Create log directory
mkdir -p "${LOG_DIR}"

# Function to setup test environment
setup_test_env() {
    status_msg "Setting up test environment" "info"
    
    # Create required directories
    mkdir -p data logs
    touch data/flows.db
    chmod -R 777 data logs
    
    # Ensure dependencies are installed
    if ! docker compose exec -T test go mod download; then
        status_msg "Failed to download Go dependencies" "error"
        return 1
    fi
    
    if ! docker compose exec -T test go mod tidy; then
        status_msg "Failed to tidy Go modules" "error"
        return 1
    fi
    
    status_msg "Test environment setup complete" "success"
    return 0
}

# Function to run tests
run_tests() {
    local test_cmd="cd /app && CGO_ENABLED=1 go test ${TEST_FLAGS} -timeout ${TEST_TIMEOUT} ${TEST_DIRS}"
    
    status_msg "Running tests with flags: ${TEST_FLAGS}" "info"
    status_msg "Test timeout: ${TEST_TIMEOUT}" "info"
    status_msg "Test directories: ${TEST_DIRS}" "info"
    echo
    
    if ! docker compose exec -T test bash -c "${test_cmd}" > "${LOG_DIR}/test.log" 2>&1; then
        status_msg "Tests failed" "error"
        cat "${LOG_DIR}/test.log"
        status_msg "Test logs saved to ${LOG_DIR}/test.log" "info"
        return 1
    fi
    
    status_msg "Tests completed successfully" "success"
    cat "${LOG_DIR}/test.log"
    return 0
}

# Function to check test environment
check_environment() {
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        status_msg "Docker is not running" "error"
        return 1
    fi
    
    # Check if test container exists
    if ! docker compose ps test >/dev/null 2>&1; then
        status_msg "Test container not found" "error"
        return 1
    fi
    
    # Check if test container is healthy
    if ! docker compose exec -T test true >/dev/null 2>&1; then
        status_msg "Test container is not responding" "error"
        return 1
    fi
    
    # Check required directories
    if [ ! -d "data" ] || [ ! -d "logs" ]; then
        status_msg "Required directories not found" "error"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    show_logo
    
    status_msg "Starting test suite" "info"
    
    # Check environment
    if ! check_environment; then
        status_msg "Environment check failed" "error"
        exit 1
    fi
    
    # Setup test environment
    if ! setup_test_env; then
        status_msg "Environment setup failed" "error"
        exit 1
    fi
    
    # Run tests
    if ! run_tests; then
        status_msg "Test suite failed" "error"
        exit 1
    fi
    
    status_msg "Test suite completed successfully" "success"
}

# Run main function
main "$@" 