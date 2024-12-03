#!/usr/bin/env bash

# Test suite for port management functions

set -euo pipefail

# Source test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_utils.sh"
source "${SCRIPT_DIR}/../ports/manager.sh"

# Test port check
test_port_check() {
    describe "port_is_in_use"
    
    # Use a random high port for testing
    local test_port=58723
    
    # Should return false when port is free
    it "returns false when port is free"
    if port_is_in_use "${test_port}"; then
        fail "Port ${test_port} reported as in use but should be free"
    fi
    
    # Start a test server
    it "returns true when port is in use"
    nc -l "${test_port}" >/dev/null 2>&1 &
    local nc_pid=$!
    sleep 1
    
    if ! port_is_in_use "${test_port}"; then
        kill "${nc_pid}" 2>/dev/null || true
        fail "Port ${test_port} reported as free but should be in use"
    fi
    
    # Cleanup
    kill "${nc_pid}" 2>/dev/null || true
    sleep 1
}

# Test get port PID
test_get_port_pid() {
    describe "get_port_pid"
    
    # Use a random high port for testing
    local test_port=58724
    
    # Should return empty when port is free
    it "returns empty when port is free"
    local pid
    pid=$(get_port_pid "${test_port}") || true
    
    if [ -n "${pid}" ]; then
        fail "Got PID ${pid} for unused port ${test_port}"
    fi
    
    # Start a test server
    it "returns correct PID when port is in use"
    nc -l "${test_port}" >/dev/null 2>&1 &
    local nc_pid=$!
    sleep 1
    
    pid=$(get_port_pid "${test_port}")
    if [ "${pid}" != "${nc_pid}" ]; then
        kill "${nc_pid}" 2>/dev/null || true
        fail "Got wrong PID ${pid}, expected ${nc_pid}"
    fi
    
    # Cleanup
    kill "${nc_pid}" 2>/dev/null || true
    sleep 1
}

# Test kill port process
test_kill_port_process() {
    describe "kill_port_process"
    
    # Use a random high port for testing
    local test_port=58725
    
    # Should handle free port gracefully
    it "handles free port gracefully"
    if kill_port_process "${test_port}"; then
        fail "kill_port_process succeeded on free port ${test_port}"
    fi
    
    # Test normal kill
    it "can kill process normally"
    nc -l "${test_port}" >/dev/null 2>&1 &
    local nc_pid=$!
    sleep 1
    
    if ! kill_port_process "${test_port}" false; then
        kill "${nc_pid}" 2>/dev/null || true
        fail "Failed to kill process on port ${test_port}"
    fi
    
    sleep 1
    if port_is_in_use "${test_port}"; then
        fail "Port ${test_port} still in use after kill"
    fi
    
    # Test force kill
    it "can force kill process"
    nc -l "${test_port}" >/dev/null 2>&1 &
    nc_pid=$!
    sleep 1
    
    if ! kill_port_process "${test_port}" true; then
        kill -9 "${nc_pid}" 2>/dev/null || true
        fail "Failed to force kill process on port ${test_port}"
    fi
    
    sleep 1
    if port_is_in_use "${test_port}"; then
        fail "Port ${test_port} still in use after force kill"
    fi
}

# Test free port
test_free_port() {
    describe "free_port"
    
    # Use a random high port for testing
    local test_port=58726
    
    # Should handle free port gracefully
    it "handles free port gracefully"
    if ! free_port "${test_port}"; then
        fail "free_port failed on already free port ${test_port}"
    fi
    
    # Test freeing used port
    it "can free used port"
    nc -l "${test_port}" >/dev/null 2>&1 &
    sleep 1
    
    if ! free_port "${test_port}"; then
        fail "Failed to free port ${test_port}"
    fi
    
    sleep 1
    if port_is_in_use "${test_port}"; then
        fail "Port ${test_port} still in use after free"
    fi
}

# Run all tests
run_test_suite() {
    test_port_check
    test_get_port_pid
    test_kill_port_process
    test_free_port
}

# Only run the tests if this script is being run directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_test_suite
fi 