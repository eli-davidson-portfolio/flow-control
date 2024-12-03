#!/usr/bin/env bash

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Shell Detection
detect_shell() {
    if [[ -n "$ZSH_VERSION" ]]; then
        echo "zsh"
    elif [[ -n "$BASH_VERSION" ]]; then
        echo "bash"
    else
        echo "unknown"
    fi
}

validate_shell() {
    local shell_type
    shell_type=$(detect_shell)
    
    case "$shell_type" in
        zsh)
            # Enable bash compatibility mode in zsh
            emulate -L bash
            setopt BASH_REMATCH
            setopt KSH_ARRAYS
            setopt PIPE_FAIL
            return 0
            ;;
        bash)
            # Check bash version
            if [[ "${BASH_VERSION%%.*}" -lt 3 ]]; then
                log_error "Bash version 3 or higher required"
                return 1
            fi
            return 0
            ;;
        *)
            log_error "Unsupported shell: $shell_type"
            log_error "Please run with bash or zsh"
            return 1
            ;;
    esac
}

# OS Detection
OS_TYPE=""
OS_VERSION=""

# Detect operating system and version
detect_os() {
    local uname_s
    uname_s=$(uname -s)
    
    case "$uname_s" in
        Darwin)
            OS_TYPE="darwin"
            OS_VERSION=$(sw_vers -productVersion)
            ;;
        Linux)
            OS_TYPE="linux"
            if [ -f /etc/os-release ]; then
                # shellcheck source=/dev/null
                . /etc/os-release
                OS_VERSION="$VERSION_ID"
            else
                OS_VERSION=$(uname -r)
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*)
            OS_TYPE="windows"
            OS_VERSION=$(uname -r)
            ;;
        *)
            OS_TYPE="unknown"
            OS_VERSION="unknown"
            ;;
    esac
    
    log_debug "Detected OS: $OS_TYPE $OS_VERSION"
    export OS_TYPE OS_VERSION
    return 0
}

# Get OS type (darwin, linux, windows)
get_os_type() {
    if [[ -z "$OS_TYPE" ]]; then
        detect_os
    fi
    echo "$OS_TYPE"
}

# Get OS version
get_os_version() {
    if [[ -z "$OS_VERSION" ]]; then
        detect_os
    fi
    echo "$OS_VERSION"
}

# Check if running on specific OS
is_darwin() {
    [[ "$(get_os_type)" == "darwin" ]]
}

is_linux() {
    [[ "$(get_os_type)" == "linux" ]]
}

is_windows() {
    [[ "$(get_os_type)" == "windows" ]]
}

# Export functions
export -f detect_shell
export -f validate_shell
export -f detect_os
export -f get_os_type
export -f get_os_version
export -f is_darwin
export -f is_linux
export -f is_windows

# Initialize on source
if ! validate_shell; then
    return 1
fi

detect_os