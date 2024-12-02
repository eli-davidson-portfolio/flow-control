#!/usr/bin/env bash

# Port management functions
# Each function is designed to be testable and handle both Linux and macOS

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../env/utils.sh"

# Check if a port is in use
port_is_in_use() {
    local port="$1"
    if lsof -i:"${port}" >/dev/null 2>&1; then
        return 0  # Port is in use
    fi
    return 1  # Port is free
}

# Get PID using a port
get_port_pid() {
    local port="$1"
    local pid
    
    # Try lsof first (works on both macOS and Linux)
    pid=$(lsof -ti:"${port}" 2>/dev/null)
    
    if [ -n "${pid}" ]; then
        echo "${pid}"
        return 0
    fi
    
    return 1
}

# Kill process using a port
kill_port_process() {
    local port="$1"
    local force="${2:-false}"
    local pid
    
    log_debug "Attempting to kill process using port ${port}..."
    
    pid=$(get_port_pid "${port}") || true
    
    if [ -n "${pid}" ]; then
        if [ "${force}" = "true" ]; then
            kill -9 "${pid}" >/dev/null 2>&1 || true
        else
            kill "${pid}" >/dev/null 2>&1 || true
        fi
        sleep 1
        return 0
    fi
    
    return 1
}

# Free a port
free_port() {
    local port="$1"
    local max_attempts="${2:-3}"
    local attempt=1
    
    log_debug "Attempting to free port ${port}..."
    
    while port_is_in_use "${port}"; do
        if [ "${attempt}" -gt "${max_attempts}" ]; then
            log_error "Failed to free port ${port} after ${max_attempts} attempts"
            return 1
        fi
        
        kill_port_process "${port}" false || true
        sleep 1
        
        if port_is_in_use "${port}"; then
            kill_port_process "${port}" true || true
            sleep 1
        fi
        
        attempt=$((attempt + 1))
    done
    
    return 0
}

# Free multiple ports
free_ports() {
    local ports=("$@")
    local failed=false
    
    for port in "${ports[@]}"; do
        if ! free_port "${port}"; then
            log_error "Failed to free port ${port}"
            failed=true
        fi
    done
    
    if [ "${failed}" = "true" ]; then
        return 1
    fi
    
    return 0
}

# Wait for a port to be available
wait_for_port() {
    local port="$1"
    local timeout="${2:-30}"
    local interval="${3:-2}"
    local elapsed=0
    
    log_debug "Waiting for port ${port} to be available..."
    
    while port_is_in_use "${port}"; do
        if [ "${elapsed}" -ge "${timeout}" ]; then
            log_error "Timeout waiting for port ${port} to be available"
            return 1
        fi
        sleep "${interval}"
        elapsed=$((elapsed + interval))
    done
    
    return 0
}

# Export functions
export -f port_is_in_use
export -f get_port_pid
export -f kill_port_process
export -f free_port
export -f free_ports
export -f wait_for_port 