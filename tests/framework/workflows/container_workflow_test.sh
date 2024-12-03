#!/bin/bash
# Test basic container workflows

source "$(dirname "$0")/../../lib/docker/docker.sh"

# Test container lifecycle workflow
test_container_lifecycle() {
    local test_container="flow-control-test-$$"
    
    log_info "Testing container lifecycle workflow..."
    
    # Pull test image
    docker pull alpine:latest >/dev/null 2>&1 || {
        log_error "Failed to pull test image"
        return 1
    }
    
    # Create test container
    docker create --name "$test_container" \
        --health-cmd "exit 0" \
        --health-interval "1s" \
        alpine:latest sleep 300 >/dev/null 2>&1 || {
        log_error "Failed to create test container"
        return 1
    }
    
    # Test container start
    start_container "$test_container" || {
        log_error "Failed to start container"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    }
    
    # Test container health check
    check_container_health "$test_container" 10 1 || {
        log_error "Container health check failed"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    }
    
    # Test container logs
    get_container_logs "$test_container" 10 || {
        log_error "Failed to get container logs"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    }
    
    # Test container stop
    stop_container "$test_container" || {
        log_error "Failed to stop container"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    }
    
    # Cleanup
    docker rm "$test_container" >/dev/null 2>&1
    
    log_info "Container lifecycle workflow test completed successfully"
    return 0
}

# Test error handling workflow
test_error_handling() {
    log_info "Testing error handling workflow..."
    
    # Test non-existent container
    start_container "nonexistent-container-$$" && {
        log_error "Start container should fail for non-existent container"
        return 1
    }
    
    # Test invalid container name
    start_container "invalid@container" && {
        log_error "Start container should fail for invalid container name"
        return 1
    }
    
    # Test container with no health check
    local test_container="flow-control-test-$$"
    docker create --name "$test_container" alpine:latest sleep 300 >/dev/null 2>&1
    
    check_container_health "$test_container" && {
        log_error "Health check should handle container with no health check"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    }
    
    # Cleanup
    docker rm -f "$test_container" >/dev/null 2>&1
    
    log_info "Error handling workflow test completed successfully"
    return 0
}

# Test logging integration workflow
test_logging_integration() {
    log_info "Testing logging integration workflow..."
    
    # Create test container with specific log message
    local test_container="flow-control-test-$$"
    docker create --name "$test_container" alpine:latest sh -c 'echo "test log message"; sleep 300' >/dev/null 2>&1 || {
        log_error "Failed to create test container"
        return 1
    }
    
    # Start container and verify logs
    start_container "$test_container" || {
        log_error "Failed to start container"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    }
    
    # Check if log message is present
    if ! get_container_logs "$test_container" | grep -q "test log message"; then
        log_error "Expected log message not found"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    fi
    
    # Cleanup
    docker rm -f "$test_container" >/dev/null 2>&1
    
    log_info "Logging integration workflow test completed successfully"
    return 0
}

# Run all workflow tests
main() {
    test_container_lifecycle || exit 1
    test_error_handling || exit 1
    test_logging_integration || exit 1
    
    log_info "All workflow tests completed successfully"
    exit 0
}

main "$@" 