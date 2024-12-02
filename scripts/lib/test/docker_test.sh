#!/usr/bin/env bash

# Test suite for Docker management functions

set -euo pipefail

# Source test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_utils.sh"
source "${SCRIPT_DIR}/../docker/manager.sh"

# Test Docker health check
test_docker_health() {
    describe "docker_check_health"
    
    # Should succeed when Docker is running
    it "returns success when Docker is running"
    if ! docker_check_health; then
        fail "Docker health check failed but Docker should be running"
    fi
    
    # TODO: Add test for Docker not running case
    # This is harder to test as it requires stopping Docker
}

# Test container operations
test_container_ops() {
    describe "container operations"
    
    # Create a test container
    it "can stop and remove containers"
    docker run -d --name test-container alpine sleep 1000 >/dev/null
    
    # Test stopping
    docker_stop_all
    if docker ps -q | grep -q .; then
        fail "Containers still running after stop_all"
    fi
    
    # Test removal
    docker_remove_all
    if docker ps -aq | grep -q .; then
        fail "Containers still exist after remove_all"
    fi
}

# Test network operations
test_network_ops() {
    describe "network operations"
    
    # Create a test network
    it "can clean networks"
    docker network create test-network >/dev/null
    
    docker_clean_networks
    
    if docker network ls | grep -q test-network; then
        fail "Test network still exists after clean_networks"
    fi
}

# Test volume operations
test_volume_ops() {
    describe "volume operations"
    
    # Create a test volume
    it "can clean volumes"
    docker volume create test-volume >/dev/null
    
    docker_clean_volumes
    
    if docker volume ls | grep -q test-volume; then
        fail "Test volume still exists after clean_volumes"
    fi
}

# Run all tests
run_test_suite() {
    test_docker_health
    test_container_ops
    test_network_ops
    test_volume_ops
}

# Only run the tests if this script is being run directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_test_suite
fi 