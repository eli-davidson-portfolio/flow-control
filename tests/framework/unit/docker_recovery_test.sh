#!/bin/bash
# Unit tests for Docker recovery functions

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/config/docker.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/docker/docker.sh"

# Test soft recovery
test_soft_recovery() {
    log_info "Testing soft recovery..."
    
    # Simulate Docker failure
    if is_darwin; then
        killall Docker || true
    else
        systemctl stop docker
    fi
    
    # Test recovery
    soft_recovery
    assert_true "Docker should be running after soft recovery" "check_docker_running"
    
    return 0
}

# Test force recovery
test_force_recovery() {
    log_info "Testing force recovery..."
    
    # Simulate Docker failure with socket issues
    if is_darwin; then
        killall -9 Docker || true
        touch "${DOCKER_CLI_SOCKET}"
    else
        systemctl stop docker
        touch "${DOCKER_SOCKET}"
    fi
    
    # Test recovery
    force_recovery
    assert_true "Docker should be running after force recovery" "check_docker_running"
    
    return 0
}

# Test full recovery
test_full_recovery() {
    log_info "Testing full recovery..."
    
    # Simulate complete Docker failure
    if is_darwin; then
        killall -9 Docker || true
        mkdir -p "${DOCKER_VM_DIR}"
        touch "${DOCKER_VM_DIR}/corrupted_vm"
        touch "${DOCKER_CLI_SOCKET}"
    else
        systemctl stop docker
        touch "${DOCKER_SOCKET}"
        mkdir -p /var/lib/docker/corrupted
    fi
    
    # Test recovery
    full_recovery
    assert_true "Docker should be running after full recovery" "check_docker_running"
    
    return 0
}

# Run tests
main() {
    test_soft_recovery || exit 1
    test_force_recovery || exit 1
    test_full_recovery || exit 1
    return 0
}

main "$@" 