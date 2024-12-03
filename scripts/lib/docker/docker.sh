#!/bin/bash

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/../config/docker_config.sh"

# Check if Docker is installed
check_docker_installed() {
    command -v docker >/dev/null 2>&1
}

# Check if Docker daemon is running
check_docker_running() {
    docker_cmd info >/dev/null 2>&1
}

# Enhanced Docker state detection for macOS
check_docker_desktop_state() {
    if ! is_darwin; then
        return 0
    fi

    # Check if Docker Desktop process is running
    if ! pgrep -f "Docker Desktop" > /dev/null; then
        log_error "Docker Desktop process is not running"
        return 1
    fi

    # Check if Docker Desktop UI is running (indicates full startup)
    if ! pgrep -f "Docker.app/Contents/MacOS/Docker" > /dev/null; then
        log_error "Docker Desktop UI is not running"
        return 1
    fi

    # Check if Docker socket exists and is accessible
    if [[ ! -S "${DOCKER_SOCKET}" ]]; then
        log_error "Docker socket not found at ${DOCKER_SOCKET}"
        return 1
    fi

    # Try basic Docker commands with short timeout
    if ! timeout 5 docker version >/dev/null 2>&1; then
        log_error "Docker daemon not responding to commands"
        return 1
    fi

    return 0
}

# Check if Docker is ready for commands with better platform awareness
check_docker_ready() {
    local timeout="${1:-$DOCKER_START_TIMEOUT}"
    local count=0
    
    while ((count < timeout)); do
        if is_darwin; then
            # For macOS, check Docker Desktop state first
            if ! check_docker_desktop_state; then
                sleep 2
                ((count+=2))
                continue
            fi
        fi

        # Try a sequence of increasingly complex Docker commands
        if docker_cmd version >/dev/null 2>&1; then
            if docker_cmd ps >/dev/null 2>&1; then
                if docker_cmd images >/dev/null 2>&1; then
                    # Final check: try to pull a tiny image
                    if docker_cmd pull hello-world >/dev/null 2>&1; then
                        return 0
                    fi
                fi
            fi
        fi
        
        sleep 2
        ((count+=2))
    done
    
    log_error "Docker not ready after ${timeout} seconds"
    return 1
}

# Check Docker environment with improved detection
check_docker_environment() {
    local quiet=false
    [[ "$1" == "--quiet" ]] && quiet=true
    
    if ! check_docker_installed; then
        [[ "$quiet" == "false" ]] && log_error "Docker is not installed"
        return 1
    fi
    
    if is_darwin; then
        if ! check_docker_desktop_state; then
            [[ "$quiet" == "false" ]] && log_error "Docker Desktop is not properly initialized"
            return 1
        fi
    else
        if ! check_docker_running; then
            [[ "$quiet" == "false" ]] && log_error "Docker daemon is not running"
            return 1
        fi
    fi
    
    return 0
}

# Cleanup operations
cleanup_containers() {
    local prefix="$1"
    log_info "Stopping containers${prefix:+ matching prefix '$prefix'}..."
    if [[ -n "$prefix" ]]; then
        local containers
        containers=$(docker_cmd ps -q --filter name="$prefix")
        if [[ -n "$containers" ]]; then
            echo "$containers" | while read -r id; do
                docker_cmd stop "$id"
                docker_cmd rm "$id"
            done
        fi
    else
        local containers
        containers=$(docker_cmd ps -q)
        if [[ -n "$containers" ]]; then
            echo "$containers" | while read -r id; do
                docker_cmd stop "$id"
                docker_cmd rm "$id"
            done
        fi
    fi
}

cleanup_volumes() {
    local prefix="$1"
    log_info "Removing volumes${prefix:+ matching prefix '$prefix'}..."
    if [[ -n "$prefix" ]]; then
        local volumes
        volumes=$(docker_cmd volume ls -q | grep "^$prefix" || true)
        if [[ -n "$volumes" ]]; then
            echo "$volumes" | while read -r vol; do
                docker_cmd volume rm "$vol"
            done
        fi
    else
        local volumes
        volumes=$(docker_cmd volume ls -q)
        if [[ -n "$volumes" ]]; then
            echo "$volumes" | while read -r vol; do
                docker_cmd volume rm "$vol"
            done
        fi
    fi
}

cleanup_networks() {
    local prefix="$1"
    log_info "Removing networks${prefix:+ matching prefix '$prefix'}..."
    if [[ -n "$prefix" ]]; then
        local networks
        networks=$(docker_cmd network ls -q | grep "^$prefix" | grep -vE '^(bridge|host|none)$' || true)
        if [[ -n "$networks" ]]; then
            echo "$networks" | while read -r net; do
                docker_cmd network rm "$net"
            done
        fi
    else
        local networks
        networks=$(docker_cmd network ls -q | grep -vE '^(bridge|host|none)$')
        if [[ -n "$networks" ]]; then
            echo "$networks" | while read -r net; do
                docker_cmd network rm "$net"
            done
        fi
    fi
}

cleanup_images() {
    local image="$1"
    log_info "Removing images${image:+ matching '$image'}..."
    if [[ -n "$image" ]]; then
        local images
        images=$(docker_cmd images "$image" -q)
        if [[ -n "$images" ]]; then
            echo "$images" | while read -r img; do
                docker_cmd rmi -f "$img"
            done
        fi
    else
        local images
        images=$(docker_cmd images -q)
        if [[ -n "$images" ]]; then
            echo "$images" | while read -r img; do
                docker_cmd rmi -f "$img"
            done
        fi
    fi
}

# Recovery operations
soft_recovery() {
    log_info "Attempting soft recovery..."
    if is_darwin; then
        killall Docker || true
        open -a Docker
    else
        systemctl restart docker
    fi
    
    check_docker_ready
}

force_recovery() {
    log_info "Attempting force recovery..."
    if is_darwin; then
        killall -9 Docker || true
        rm -f "${DOCKER_CLI_SOCKET}"
        open -a Docker
    else
        systemctl stop docker
        rm -f "${DOCKER_SOCKET}"
        systemctl start docker
    fi
    
    check_docker_ready
}

full_recovery() {
    log_info "Attempting full recovery..."
    if is_darwin; then
        killall -9 Docker || true
        rm -f "${DOCKER_CLI_SOCKET}"
        rm -rf "${DOCKER_VM_DIR}"
        rm -rf "${DOCKER_DESKTOP_DIR}"
        open -a Docker
    else
        systemctl stop docker
        rm -f "${DOCKER_SOCKET}"
        rm -rf /var/lib/docker/*
        systemctl start docker
    fi
    
    check_docker_ready
}

# Export functions
export -f check_docker_installed
export -f check_docker_running
export -f check_docker_environment
export -f cleanup_containers
export -f cleanup_volumes
export -f cleanup_networks
export -f cleanup_images
export -f soft_recovery
export -f force_recovery
export -f full_recovery
export -f check_docker_ready
export -f check_docker_desktop_state