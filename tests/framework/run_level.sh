#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source framework configuration and helpers
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/helpers.sh"

# Check arguments
if [ $# -ne 1 ]; then
    log_error "Usage: $0 <test-level>"
    exit 1
fi

LEVEL=$1

# Validate test level
if ! is_valid_test_level "$LEVEL"; then
    log_error "Invalid test level: $LEVEL"
    log_info "Available levels: ${!TEST_LEVELS[*]}"
    exit 1
fi

# Check dependencies
if ! check_dependencies "$LEVEL"; then
    log_error "Missing dependencies for level $LEVEL"
    exit 1
fi

# Setup test environment
setup_test_env "$LEVEL"

# Run tests for the level
log_header "Running ${TEST_LEVELS[$LEVEL]} ($LEVEL)"

# Run Go tests
if [ -d "$PROJECT_ROOT/tests/$LEVEL/go" ]; then
    log_step "Running Go tests for $LEVEL"
    find "$PROJECT_ROOT/tests/$LEVEL/go" -name "*_test.go" -exec dirname {} \; | sort -u | while read -r pkg; do
        (cd "$pkg" && go test -v ./...)
    done
fi

# Run shell tests
if [ -d "$PROJECT_ROOT/tests/$LEVEL/shell" ]; then
    log_step "Running shell tests for $LEVEL"
    find "$PROJECT_ROOT/tests/$LEVEL/shell" -name "*.sh" -type f | while read -r test; do
        run_test "$LEVEL" "$test"
    done
fi

# Cleanup test environment
cleanup_test_env "$LEVEL"

log_success "Test level $LEVEL completed" 