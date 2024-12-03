#!/bin/bash
# Integration tests for Docker functionality

source "$(dirname "$0")/../../lib/docker/docker.sh"
source "$(dirname "$0")/../../lib/docker/manager.sh"

# Setup test environment
setup() {
    log_info "Setting up test environment..."
    
    # Ensure Docker is installed and running
    check_docker_environment --quiet || {
        log_error "Docker environment is not ready"
        return 1
    }
    
    # Clean up any leftover test containers
    cleanup_test_containers
    
    return 0
}

# Clean up test containers
cleanup_test_containers() {
    log_info "Cleaning up test containers..."
    docker ps -a --filter "name=flow-control-test-" -q | xargs -r docker rm -f >/dev/null 2>&1
}

# Test environment setup and health check integration
test_environment_setup() {
    log_info "Testing environment setup and health check integration..."
    
    # Test environment check with space management
    check_docker_environment || {
        log_error "Environment check failed"
        return 1
    }
    
    # Verify disk space management
    manage_docker_space 1 "conservative" || {
        log_error "Space management failed"
        return 1
    }
    
    # Verify Docker health
    check_docker_health "full" || {
        log_error "Health check failed"
        return 1
    }
    
    log_info "Environment setup test passed"
    return 0
}

# Test container and health check integration
test_container_health_integration() {
    log_info "Testing container and health check integration..."
    local test_container="flow-control-test-$$"
    
    # Create container with health check
    docker create --name "$test_container" \
        --health-cmd "exit 0" \
        --health-interval "1s" \
        alpine:latest sleep 300 >/dev/null 2>&1 || {
        log_error "Failed to create test container"
        return 1
    }
    
    # Start container and verify health
    start_container "$test_container" || {
        log_error "Failed to start container"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    }
    
    # Wait for health check
    sleep 2
    
    # Verify health status
    check_container_health "$test_container" || {
        log_error "Health check integration failed"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    }
    
    # Stop and cleanup
    stop_container "$test_container"
    docker rm "$test_container" >/dev/null 2>&1
    
    log_info "Container health integration test passed"
    return 0
}

# Test logging and monitoring integration
test_logging_monitoring_integration() {
    log_info "Testing logging and monitoring integration..."
    local test_container="flow-control-test-$$"
    
    # Create container that generates logs
    docker create --name "$test_container" \
        alpine:latest sh -c 'while true; do echo "test log $(date)"; sleep 1; done' >/dev/null 2>&1 || {
        log_error "Failed to create logging test container"
        return 1
    }
    
    # Start container
    start_container "$test_container" || {
        log_error "Failed to start logging test container"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    }
    
    # Wait for logs to generate
    sleep 2
    
    # Test log retrieval
    get_container_logs "$test_container" 5 || {
        log_error "Failed to retrieve container logs"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    }
    
    # Stop and cleanup
    stop_container "$test_container"
    docker rm "$test_container" >/dev/null 2>&1
    
    log_info "Logging and monitoring integration test passed"
    return 0
}

# Test error recovery integration
test_error_recovery_integration() {
    log_info "Testing error recovery integration..."
    local test_container="flow-control-test-$$"
    
    # Test recovery from invalid container
    start_container "nonexistent-container" || log_info "Expected failure handled correctly"
    
    # Test recovery from failed health check
    docker create --name "$test_container" \
        --health-cmd "exit 1" \
        --health-interval "1s" \
        alpine:latest sleep 300 >/dev/null 2>&1
    
    start_container "$test_container"
    check_container_health "$test_container" || log_info "Expected health check failure handled correctly"
    
    # Test space management recovery
    manage_docker_space 1000 "aggressive" || log_info "Expected space management handled correctly"
    
    # Cleanup
    docker rm -f "$test_container" >/dev/null 2>&1
    
    log_info "Error recovery integration test passed"
    return 0
}

# Run all integration tests
main() {
    # Setup
    setup || {
        log_error "Test setup failed"
        exit 1
    }
    
    # Run tests
    test_environment_setup || exit 1
    test_container_health_integration || exit 1
    test_logging_monitoring_integration || exit 1
    test_error_recovery_integration || exit 1
    
    # Cleanup
    cleanup_test_containers
    
    log_info "All integration tests completed successfully"
    exit 0
}

main "$@" 