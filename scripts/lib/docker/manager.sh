#!/usr/bin/env bash

# Docker management functions
# Each function is designed to be testable and handle both Linux and macOS

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../env/utils.sh"

# Stop all containers
docker_stop_all() {
    log_debug "Stopping all Docker containers..."
    docker stop $(docker ps -aq) >/dev/null 2>&1 || true
    return 0
}

# Remove all containers
docker_remove_all() {
    log_debug "Removing all Docker containers..."
    docker rm -f $(docker ps -aq) >/dev/null 2>&1 || true
    return 0
}

# Remove all images
docker_remove_images() {
    log_debug "Removing all Docker images..."
    docker rmi -f $(docker images -aq) >/dev/null 2>&1 || true
    return 0
}

# Clean volumes
docker_clean_volumes() {
    log_debug "Cleaning Docker volumes..."
    docker volume rm $(docker volume ls -q) >/dev/null 2>&1 || true
    return 0
}

# Clean networks
docker_clean_networks() {
    log_debug "Cleaning Docker networks..."
    docker network prune -f >/dev/null 2>&1 || true
    return 0
}

# Clean build cache
docker_clean_cache() {
    log_debug "Cleaning Docker build cache..."
    docker builder prune -af >/dev/null 2>&1 || true
    return 0
}

# Restart Docker (platform specific)
docker_restart() {
    local platform="$(uname)"
    log_info "Restarting Docker on ${platform}..."
    
    if [ "${platform}" = "Darwin" ]; then
        # macOS: Restart Docker Desktop
        osascript -e 'quit app "Docker Desktop"' >/dev/null 2>&1 || true
        sleep 2
        open -a Docker
        log_info "Waiting for Docker Desktop to restart..."
        until docker info >/dev/null 2>&1; do 
            sleep 2
            log_debug "Still waiting for Docker..."
        done
    else
        # Linux: Restart Docker daemon
        sudo systemctl restart docker >/dev/null 2>&1 || true
    fi
    
    # Wait for Docker to be fully ready
    sleep 5
    log_info "Docker restart complete"
    return 0
}

# Force cleanup everything
docker_force_cleanup() {
    log_info "Performing force cleanup of Docker environment..."
    
    docker_stop_all
    docker_remove_all
    docker_remove_images
    docker_clean_volumes
    docker_clean_networks
    docker_clean_cache
    docker_restart
    
    log_info "Force cleanup complete"
    return 0
}

# Check if Docker is healthy
docker_check_health() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running or not accessible"
        return 1
    fi
    return 0
}

# Export functions
export -f docker_stop_all
export -f docker_remove_all
export -f docker_remove_images
export -f docker_clean_volumes
export -f docker_clean_networks
export -f docker_clean_cache
export -f docker_restart
export -f docker_force_cleanup
export -f docker_check_health 