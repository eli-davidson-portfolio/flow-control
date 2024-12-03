#!/bin/bash

# Core Validation Library
# Provides input validation and environment checking functionality

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Exit codes
EXIT_SUCCESS=0
EXIT_INVALID_INPUT=1
EXIT_MISSING_DEPENDENCY=2
EXIT_INVALID_ENV=3

# Regular expressions for validation
EMAIL_REGEX='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
URL_REGEX='^https?://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/.*)?$'
VERSION_REGEX='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
DOMAIN_REGEX='^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'

# Input validation functions
validate_string() {
    local input="$1"
    local min_length="${2:-1}"
    local max_length="${3:-255}"
    local pattern="${4:-'^[A-Za-z0-9 _-]*$'}"
    
    if [[ -z "$input" ]]; then
        log_error "Input is empty"
        return $EXIT_INVALID_INPUT
    fi
    
    if (( ${#input} < min_length )); then
        log_error "Input is too short (minimum $min_length characters)"
        return $EXIT_INVALID_INPUT
    fi
    
    if (( ${#input} > max_length )); then
        log_error "Input is too long (maximum $max_length characters)"
        return $EXIT_INVALID_INPUT
    fi
    
    if ! echo "$input" | grep -qE "$pattern"; then
        log_error "Input contains invalid characters"
        return $EXIT_INVALID_INPUT
    fi
    
    return $EXIT_SUCCESS
}

validate_number() {
    local input="$1"
    local min="${2:-}"
    local max="${3:-}"
    
    if ! [[ "$input" =~ ^-?[0-9]+$ ]]; then
        log_error "Input is not a valid number"
        return $EXIT_INVALID_INPUT
    fi
    
    if [[ -n "$min" ]] && (( input < min )); then
        log_error "Input is below minimum value ($min)"
        return $EXIT_INVALID_INPUT
    fi
    
    if [[ -n "$max" ]] && (( input > max )); then
        log_error "Input is above maximum value ($max)"
        return $EXIT_INVALID_INPUT
    fi
    
    return $EXIT_SUCCESS
}

validate_email() {
    local email="$1"
    
    if ! echo "$email" | grep -qE "$EMAIL_REGEX"; then
        log_error "Invalid email address"
        return $EXIT_INVALID_INPUT
    fi
    
    return $EXIT_SUCCESS
}

validate_url() {
    local url="$1"
    
    if ! echo "$url" | grep -qE "$URL_REGEX"; then
        log_error "Invalid URL"
        return $EXIT_INVALID_INPUT
    fi
    
    return $EXIT_SUCCESS
}

validate_version() {
    local version="$1"
    local required_version="$2"
    
    if ! echo "$version" | grep -qE "$VERSION_REGEX"; then
        log_error "Invalid version format"
        return $EXIT_INVALID_INPUT
    fi
    
    if [[ -n "$required_version" ]]; then
        if ! command -v sort >/dev/null; then
            log_error "sort command not found"
            return $EXIT_MISSING_DEPENDENCY
        fi
        
        if [[ "$(printf '%s\n' "$version" "$required_version" | sort -V | head -n1)" != "$required_version" ]]; then
            log_error "Version $version is older than required version $required_version"
            return $EXIT_INVALID_INPUT
        fi
    fi
    
    return $EXIT_SUCCESS
}

# Environment validation functions
validate_path() {
    local path="$1"
    local check_type="$2" # file, directory, any
    local check_perms="$3" # r, w, x or combination
    
    # Check existence
    case "$check_type" in
        "file")
            if [[ ! -f "$path" ]]; then
                log_error "File not found: $path"
                return $EXIT_INVALID_ENV
            fi
            ;;
        "directory")
            if [[ ! -d "$path" ]]; then
                log_error "Directory not found: $path"
                return $EXIT_INVALID_ENV
            fi
            ;;
        "any")
            if [[ ! -e "$path" ]]; then
                log_error "Path not found: $path"
                return $EXIT_INVALID_ENV
            fi
            ;;
        *)
            log_error "Invalid check type: $check_type"
            return $EXIT_INVALID_INPUT
            ;;
    esac
    
    # Check permissions
    if [[ -n "$check_perms" ]]; then
        [[ "$check_perms" == *"r"* ]] && [[ ! -r "$path" ]] && {
            log_error "No read permission: $path"
            return $EXIT_INVALID_ENV
        }
        [[ "$check_perms" == *"w"* ]] && [[ ! -w "$path" ]] && {
            log_error "No write permission: $path"
            return $EXIT_INVALID_ENV
        }
        [[ "$check_perms" == *"x"* ]] && [[ ! -x "$path" ]] && {
            log_error "No execute permission: $path"
            return $EXIT_INVALID_ENV
        }
    fi
    
    return $EXIT_SUCCESS
}

validate_command() {
    local command="$1"
    local min_version="$2"
    
    if ! command -v "$command" >/dev/null; then
        log_error "Command not found: $command"
        return $EXIT_MISSING_DEPENDENCY
    fi
    
    if [[ -n "$min_version" ]]; then
        local version
        version=$("$command" --version 2>/dev/null | grep -oE "$VERSION_REGEX" | head -n1)
        
        if ! validate_version "$version" "$min_version"; then
            log_error "Command $command version $version is older than required version $min_version"
            return $EXIT_INVALID_ENV
        fi
    fi
    
    return $EXIT_SUCCESS
}

validate_network() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"
    
    # Check if host is reachable
    if ! ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
        log_error "Host not reachable: $host"
        return $EXIT_INVALID_ENV
    fi
    
    # Check if port is open (if specified)
    if [[ -n "$port" ]]; then
        if ! nc -z -w "$timeout" "$host" "$port" >/dev/null 2>&1; then
            log_error "Port $port not accessible on host $host"
            return $EXIT_INVALID_ENV
        fi
    fi
    
    return $EXIT_SUCCESS
}

validate_dependencies() {
    local -a missing_deps=()
    local command min_version
    
    while (( $# >= 1 )); do
        command="$1"
        min_version="${2:-}"
        
        if ! validate_command "$command" "$min_version"; then
            missing_deps+=("$command${min_version:+ (>=$min_version)}")
        fi
        
        if [[ -n "$min_version" ]]; then
            shift 2
        else
            shift
        fi
    done
    
    if (( ${#missing_deps[@]} > 0 )); then
        log_error "Missing dependencies: ${missing_deps[*]}"
        return $EXIT_MISSING_DEPENDENCY
    fi
    
    return $EXIT_SUCCESS
}

validate_environment() {
    local -a required_vars=("$@")
    local -a missing_vars=()
    local var
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if (( ${#missing_vars[@]} > 0 )); then
        log_error "Missing environment variables: ${missing_vars[*]}"
        return $EXIT_INVALID_ENV
    fi
    
    return $EXIT_SUCCESS
}

validate_permissions() {
    local path="$1"
    local required_perms="$2"
    local current_perms
    
    if [[ ! -e "$path" ]]; then
        log_error "Path not found: $path"
        return $EXIT_INVALID_ENV
    fi
    
    current_perms=$(stat -f "%Lp" "$path" 2>/dev/null || stat -c "%a" "$path" 2>/dev/null)
    
    if ! [[ "$current_perms" =~ ^[0-7]{3,4}$ ]]; then
        log_error "Failed to get permissions for: $path"
        return $EXIT_INVALID_ENV
    fi
    
    if (( current_perms & required_perms != required_perms )); then
        log_error "Insufficient permissions for $path (required: $required_perms, current: $current_perms)"
        return $EXIT_INVALID_ENV
    fi
    
    return $EXIT_SUCCESS
}