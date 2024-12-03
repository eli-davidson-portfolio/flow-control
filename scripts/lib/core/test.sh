#!/bin/bash
# Core test functions for Flow Control project

# Source common dependencies
source "$(dirname "$0")/../config/config.sh"
source "$(dirname "$0")/../docker/docker.sh"

# Test configuration defaults
DEFAULT_TEST_TIMEOUT="5m"
DEFAULT_COVERAGE_DIR="coverage"

# Configure test parameters and return formatted test flags
# Usage: configure_test_flags [--coverage] [--race] [--integration] [--verbose] [--failfast]
configure_test_flags() {
    local coverage_enabled=false
    local race_detection=false
    local integration_tests=false
    local verbose_output=false
    local fail_fast=false
    local test_flags=""
    local test_pattern=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --coverage)
                coverage_enabled=true
                shift
                ;;
            --race)
                race_detection=true
                shift
                ;;
            --integration)
                integration_tests=true
                shift
                ;;
            --verbose)
                verbose_output=true
                shift
                ;;
            --failfast)
                fail_fast=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Build test flags
    if [[ "$coverage_enabled" == "true" ]]; then
        mkdir -p "$DEFAULT_COVERAGE_DIR"
        test_flags="$test_flags -coverprofile=$DEFAULT_COVERAGE_DIR/coverage.out"
    fi
    
    if [[ "$race_detection" == "true" ]]; then
        test_flags="$test_flags -race"
    fi
    
    if [[ "$verbose_output" == "true" ]]; then
        test_flags="$test_flags -v"
    fi
    
    if [[ "$fail_fast" == "true" ]]; then
        test_flags="$test_flags -failfast"
    fi
    
    if [[ "$integration_tests" == "true" ]]; then
        test_pattern="Integration"
    fi
    
    # Export variables for use in calling script
    export TEST_FLAGS="$test_flags"
    export TEST_PATTERN="$test_pattern"
    export TEST_TIMEOUT="${TEST_TIMEOUT:-$DEFAULT_TEST_TIMEOUT}"
    export COVERAGE_ENABLED="$coverage_enabled"
}

# Run tests in Docker environment
run_tests_in_docker() {
    local test_flags="$1"
    local test_pattern="$2"
    local test_timeout="$3"
    
    # Ensure Docker environment is ready
    if ! check_docker_environment --quiet; then
        log_error "Docker environment is not ready"
        return 1
    fi
    
    # Run go mod tidy
    log_info "Running go mod tidy in Docker..."
    if ! docker-compose run --rm test go mod tidy; then
        log_error "Failed to run go mod tidy in Docker"
        return 1
    fi
    
    # Run tests
    log_info "Running tests in Docker..."
    docker-compose run --rm test go test $test_flags -timeout=$test_timeout ${test_pattern:+-run=$test_pattern} ./...
}

# Generate and display coverage report
generate_coverage_report() {
    local coverage_profile="$DEFAULT_COVERAGE_DIR/coverage.out"
    local coverage_html="$DEFAULT_COVERAGE_DIR/coverage.html"
    
    if [[ ! -f "$coverage_profile" ]]; then
        log_error "Coverage profile not found: $coverage_profile"
        return 1
    fi
    
    log_info "Generating coverage report..."
    docker-compose run --rm test go tool cover -html="$coverage_profile" -o "$coverage_html"
    
    # Print coverage summary
    local coverage_pct
    coverage_pct=$(docker-compose run --rm test go tool cover -func="$coverage_profile" | grep total | awk '{print $3}')
    log_info "Total coverage: $coverage_pct"
    
    # Open coverage report in browser if not in CI
    if [[ -z "$CI" ]]; then
        case "$(uname)" in
            Darwin)
                open "$coverage_html"
                ;;
            Linux)
                if command -v xdg-open &>/dev/null; then
                    xdg-open "$coverage_html"
                fi
                ;;
        esac
    fi
} 