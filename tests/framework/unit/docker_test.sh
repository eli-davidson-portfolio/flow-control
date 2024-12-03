#!/bin/bash
# Unit tests for Docker management functions

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/config/docker_config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/docker/docker.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../test/framework.sh"

# Test timeouts
export TEST_CASE_TIMEOUT=30  # 30 seconds per test case

# Test cleanup operations
test_cleanup_operations() {
    log_info "Running tests on $(get_os_type) $(get_os_version)"
    
    # Ensure Docker is running with timeout
    if is_darwin; then
        if ! timeout 30 check_docker_desktop_state; then
            log_error "Docker Desktop is not running or not properly initialized"
            return 1
        fi
    else
        if ! timeout 30 check_docker_environment; then
            log_error "Docker daemon is not running"
            return 1
        fi
    fi
    
    # Pull test image with timeout
    log_info "Pulling required test images..."
    if ! timeout 60 docker_cmd pull alpine:latest; then
        log_error "Failed to pull alpine:latest image"
        return 1
    fi
    
    # Create test containers with unique identifiers
    local test_prefix="flow-control-test-${RANDOM}"
    if ! timeout 30 docker_cmd run -d --name "${test_prefix}-1" alpine:latest sleep 300; then
        log_error "Failed to create first test container"
        return 1
    fi
    if ! timeout 30 docker_cmd run -d --name "${test_prefix}-2" alpine:latest sleep 300; then
        log_error "Failed to create second test container"
        return 1
    fi
    
    # Test container cleanup with timeout
    if ! timeout 30 cleanup_containers "${test_prefix}"; then
        log_error "Container cleanup timed out"
        return 1
    fi
    
    # Verify container cleanup
    assert_true "Should stop test containers" "! timeout 10 docker_cmd ps -q --filter name=${test_prefix} | grep -q ."
    assert_true "Test containers should be removed" "! timeout 10 docker_cmd ps -a -q --filter name=${test_prefix} | grep -q ."
    
    # Test volume cleanup with timeout
    local test_volume="${test_prefix}-vol"
    if ! timeout 30 docker_cmd volume create "$test_volume"; then
        log_error "Failed to create test volume"
        return 1
    fi
    if ! timeout 30 cleanup_volumes "$test_volume"; then
        log_error "Volume cleanup timed out"
        return 1
    fi
    assert_true "Should clean test volume" "! timeout 10 docker_cmd volume ls -q | grep -q ${test_volume}"
    
    # Test network cleanup with timeout
    local test_network="${test_prefix}-net"
    if ! timeout 30 docker_cmd network create "$test_network"; then
        log_error "Failed to create test network"
        return 1
    fi
    if ! timeout 30 cleanup_networks "$test_network"; then
        log_error "Network cleanup timed out"
        return 1
    fi
    assert_true "Should clean test network" "! timeout 10 docker_cmd network ls -q | grep -q ${test_network}"
    assert_true "Should preserve system networks" "timeout 10 docker_cmd network ls -q | grep -E 'bridge|host|none'"
    
    # Test image cleanup with timeout
    if ! timeout 30 cleanup_images "alpine:latest"; then
        log_error "Image cleanup timed out"
        return 1
    fi
    assert_true "Should clean build cache" "timeout 10 docker_cmd builder prune -f >/dev/null 2>&1"
    
    # Verify cleanup with timeout
    if ! timeout 60 force_recovery; then
        log_error "Force recovery timed out"
        return 1
    fi
    assert_true "No test containers should remain" "! timeout 10 docker_cmd ps -a -q --filter name=${test_prefix} | grep -q ."
    assert_true "No test volumes should remain" "! timeout 10 docker_cmd volume ls -q | grep -q ${test_prefix}"
    assert_true "No test networks should remain" "! timeout 10 docker_cmd network ls -q | grep -q ${test_prefix}"
    
    return 0
}

# Test error handling
test_error_handling() {
    log_info "Running tests on $(get_os_type) $(get_os_version)"
    
    # Ensure Docker is running
    check_docker_environment || {
        log_error "Cannot proceed with tests - Docker is not running"
        return 1
    }
    
    # Clean up test environment
    log_info "Cleaning up test environment..."
    force_recovery
    
    # Pull required images
    log_info "Pulling required test images..."
    docker_cmd pull alpine:latest || {
        log_error "Failed to pull alpine:latest image"
        return 1
    }
    
    # Test invalid container operations
    assert_false "Should fail on invalid container" "docker_cmd start nonexistent-container"
    assert_false "Should fail on invalid network" "docker_cmd network connect nonexistent-network nonexistent-container"
    assert_false "Should fail on invalid volume" "docker_cmd volume inspect nonexistent-volume"
    
    return 0
}

# Run tests
main() {
    test_cleanup_operations || exit 1
    test_error_handling || exit 1
    return 0
}

main "$@"