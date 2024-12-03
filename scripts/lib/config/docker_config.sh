#!/bin/bash
# Docker configuration management
# Centralizes all Docker-related paths and settings

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/../core/config_base.sh"

# Base paths
if [[ -z "$DOCKER_BASE_DIR" ]]; then
    DOCKER_BASE_DIR="${HOME}/.docker"
    DOCKER_DATA_BASE_DIR="${HOME}/Library/Containers/com.docker.docker"
    DOCKER_GROUP_BASE_DIR="${HOME}/Library/Group Containers/group.com.docker"
fi

# Socket paths
if [[ -z "$DOCKER_SOCKET" ]]; then
    if is_darwin; then
        # Check for Docker Desktop socket first
        if [[ -S "${HOME}/.docker/run/docker.sock" ]]; then
            DOCKER_SOCKET="${HOME}/.docker/run/docker.sock"
        else
            DOCKER_SOCKET="/var/run/docker.sock"
        fi
        DOCKER_CLI_SOCKET="${DOCKER_BASE_DIR}/run/docker.sock"
    else
        DOCKER_SOCKET="/var/run/docker.sock"
        DOCKER_CLI_SOCKET="/var/run/docker.sock"
    fi
fi

# Configuration paths
if [[ -z "$DOCKER_CONFIG_DIR" ]]; then
    DOCKER_CONFIG_DIR="${DOCKER_BASE_DIR}"
    DOCKER_SETTINGS_FILE="${DOCKER_GROUP_BASE_DIR}/settings.json"
    DOCKER_COMPOSE_FILE="${PWD}/docker-compose.yml"
fi

# Data paths
if [[ -z "$DOCKER_DATA_DIR" ]]; then
    DOCKER_DATA_DIR="${DOCKER_DATA_BASE_DIR}/Data"
    DOCKER_VM_DIR="${DOCKER_DATA_DIR}/vms"
    DOCKER_DESKTOP_DIR="${DOCKER_BASE_DIR}/desktop"
fi

# Runtime paths
if [[ -z "$DOCKER_PID_FILE" ]]; then
    DOCKER_PID_FILE="/var/run/docker.pid"
    DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
fi

# Timeouts and limits
if [[ -z "$DOCKER_START_TIMEOUT" ]]; then
    DOCKER_START_TIMEOUT=30
    DOCKER_STOP_TIMEOUT=10
    DOCKER_PULL_TIMEOUT=300
    DOCKER_BUILD_TIMEOUT=600
    DOCKER_HEALTH_CHECK_INTERVAL=1
    DOCKER_MAX_RETRIES=3
fi

# Export all variables
export DOCKER_SOCKET
export DOCKER_CLI_SOCKET
export DOCKER_CONFIG_DIR
export DOCKER_DATA_DIR
export DOCKER_VM_DIR
export DOCKER_DESKTOP_DIR
export DOCKER_PID_FILE
export DOCKER_DAEMON_JSON
export DOCKER_START_TIMEOUT
export DOCKER_STOP_TIMEOUT
export DOCKER_PULL_TIMEOUT
export DOCKER_BUILD_TIMEOUT
export DOCKER_HEALTH_CHECK_INTERVAL
export DOCKER_MAX_RETRIES

# Docker command wrapper
docker_cmd() {
    docker "$@"
}
export -f docker_cmd 

# Docker Desktop status check for macOS
check_docker_desktop() {
    if ! is_darwin; then
        return 0
    fi
    
    # Check if Docker Desktop is running
    if ! pgrep -f "Docker Desktop" > /dev/null; then
        log_error "Docker Desktop is not running on macOS"
        return 1
    fi
    
    # Wait for socket to be available
    local timeout=${DOCKER_START_TIMEOUT:-30}
    local count=0
    while [[ ! -S "$DOCKER_SOCKET" ]] && ((count < timeout)); do
        sleep 1
        ((count++))
    done
    
    [[ -S "$DOCKER_SOCKET" ]] || {
        log_error "Docker socket not available after ${timeout}s"
        return 1
    }
    
    return 0
}
export -f check_docker_desktop