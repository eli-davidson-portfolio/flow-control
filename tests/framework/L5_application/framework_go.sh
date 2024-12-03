#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"

# Source test framework
source "$TEST_ROOT/framework.sh"

# Go test configuration
GO_TEST_TIMEOUT="30s"
GO_TEST_COVERAGE_DIR="$PROJECT_ROOT/coverage/go"

# Run Go tests for a specific package
run_go_tests() {
    local package=$1
    local extra_args=${2:-""}
    
    log_info "Running Go tests for package: $package"
    
    # Ensure coverage directory exists
    mkdir -p "$GO_TEST_COVERAGE_DIR"
    
    # Run tests
    if ! cd "$PROJECT_ROOT" && go test -v -timeout "$GO_TEST_TIMEOUT" "./internal/$package" -coverprofile="$GO_TEST_COVERAGE_DIR/$package.out"; then
        log_error "Go tests failed for package: $package"
        return 1
    fi
    
    log_success "Go tests passed for package: $package"
    return 0
}

# Run all Go tests
run_all_go_tests() {
    log_header "Running all Go tests"
    
    local packages=(
        "config"
        "flow"
        "parser"
        "runtime"
        "server"
        "store"
    )
    
    local failed=0
    for pkg in "${packages[@]}"; do
        if ! run_go_tests "$pkg"; then
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -gt 0 ]; then
        log_error "$failed Go test packages failed"
        return 1
    fi
    
    log_success "All Go tests passed"
    return 0
}

# Setup Go test environment
setup_go_tests() {
    log_header "Setting up Go test environment"
    
    # Initialize bridge
    if ! init_bridge; then
        log_error "Failed to initialize bridge"
        return 1
    fi
    
    # Run Go tests
    if ! run_all_go_tests; then
        log_error "Go tests must pass before running shell tests"
        return 1
    fi
    
    log_success "Go test environment ready"
    return 0
}

# Clean up Go test artifacts
cleanup_go_tests() {
    log_info "Cleaning up Go test artifacts"
    cleanup_bridge
    rm -rf "$GO_TEST_COVERAGE_DIR"
    log_success "Go test cleanup complete"
}

# If running directly, run tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_go_tests
fi 