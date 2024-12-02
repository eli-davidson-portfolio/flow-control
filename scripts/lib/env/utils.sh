#!/usr/bin/env bash

# Common utility functions
# Each function is designed to be testable and handle both Linux and macOS

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Current log level (default: info)
CURRENT_LOG_LEVEL="${LOG_LEVEL:-info}"

# Get numeric value for log level
get_log_level_value() {
    local level="$1"
    case "$level" in
        error)   echo "0" ;;
        warning) echo "1" ;;
        info)    echo "2" ;;
        debug)   echo "3" ;;
        *)       echo "2" ;; # Default to info level
    esac
}

# Check if we should log at this level
should_log() {
    local level="$1"
    local current_value
    local level_value
    
    current_value=$(get_log_level_value "${CURRENT_LOG_LEVEL}")
    level_value=$(get_log_level_value "${level}")
    
    [ "${level_value}" -le "${current_value}" ]
}

# Generic log function
log_message() {
    local level="$1"
    local message="$2"
    local color="$3"
    
    if should_log "${level}"; then
        echo -e "${color}[${level^^}]${NC} ${message}"
    fi
}

# Error logging
log_error() {
    log_message "error" "$1" "${RED}"
}

# Warning logging
log_warning() {
    log_message "warning" "$1" "${YELLOW}"
}

# Info logging
log_info() {
    log_message "info" "$1" "${GREEN}"
}

# Debug logging
log_debug() {
    log_message "debug" "$1" "${BLUE}"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get OS type
get_os() {
    uname -s
}

# Get OS version
get_os_version() {
    local os
    os=$(get_os)
    
    case "${os}" in
        Darwin)
            sw_vers -productVersion
            ;;
        Linux)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                echo "${VERSION_ID}"
            else
                uname -r
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if running on CI
is_ci() {
    [ -n "${CI:-}" ]
}

# Check if running in debug mode
is_debug() {
    [ "${CURRENT_LOG_LEVEL}" = "debug" ]
}

# Get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Export functions
export -f get_log_level_value
export -f should_log
export -f log_message
export -f log_error
export -f log_warning
export -f log_info
export -f log_debug
export -f command_exists
export -f get_os
export -f get_os_version
export -f is_ci
export -f is_debug
export -f get_timestamp

# Export variables
export RED
export GREEN
export YELLOW
export BLUE
export NC
export CURRENT_LOG_LEVEL 