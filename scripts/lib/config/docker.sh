#!/bin/bash
# Docker configuration management
# Centralizes all Docker-related paths and settings

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"

# Base paths
readonly DOCKER_BASE_DIR="${HOME}/.docker"
readonly DOCKER_DATA_BASE_DIR="${HOME}/Library/Containers/com.docker.docker"
readonly DOCKER_GROUP_BASE_DIR="${HOME}/Library/Group Containers/group.com.docker"

# Socket paths
readonly DOCKER_SOCKET="$(get_docker_socket)"
readonly DOCKER_CLI_SOCKET="${DOCKER_BASE_DIR}/run/docker.sock"

# Configuration paths
readonly DOCKER_CONFIG_DIR="${DOCKER_BASE_DIR}"
readonly DOCKER_SETTINGS_FILE="${DOCKER_GROUP_BASE_DIR}/settings.json"
readonly DOCKER_COMPOSE_FILE="${PWD}/docker-compose.yml"

# Data paths
readonly DOCKER_DATA_DIR="${DOCKER_DATA_BASE_DIR}/Data"
readonly DOCKER_VM_DIR="${DOCKER_DATA_DIR}/vms"
readonly DOCKER_DESKTOP_DIR="${DOCKER_BASE_DIR}/desktop"

# Runtime paths
readonly DOCKER_PID_FILE="$(get_docker_pid_file)"
readonly DOCKER_DAEMON_JSON="/etc/docker/daemon.json"

# Timeouts and limits
readonly DOCKER_START_TIMEOUT="$(get_recovery_timeout soft)"
readonly DOCKER_STOP_TIMEOUT=10
readonly DOCKER_PULL_TIMEOUT=300
readonly DOCKER_BUILD_TIMEOUT=600
readonly DOCKER_HEALTH_CHECK_INTERVAL="$(get_health_check interval)"
readonly DOCKER_MAX_RETRIES="$(get_health_check retries)"

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