#!/bin/bash
# docker-check.sh
#
# Purpose:
#   Ensures Docker environment is ready and running.
#   This script will not fall back to local execution - Docker is required.
#   If Docker is not installed or not running, it will attempt to fix the situation.

set -e

# Source required libraries
source "$(dirname "$0")/common/init.sh"
source "$(dirname "$0")/lib/docker/docker.sh"

# Constants
MIN_DOCKER_VERSION="20.10.0"
REQUIRED_PORTS=(8081)
MIN_MEMORY_GB=4
MIN_CPU_CORES=2

# Parse flags
QUIET=false
NO_COMPOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --quiet)
            QUIET=true
            shift
            ;;
        --no-compose)
            NO_COMPOSE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check Docker version
check_docker_version() {
    local current_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    if [[ "$(printf '%s\n' "$MIN_DOCKER_VERSION" "$current_version" | sort -V | head -n1)" != "$MIN_DOCKER_VERSION" ]]; then
        log_error "Docker version $current_version is below minimum required version $MIN_DOCKER_VERSION"
        return 1
    fi
}

# Check system resources
check_system_resources() {
    local total_memory_gb
    local cpu_cores
    
    case "$(uname)" in
        "Darwin")
            total_memory_gb=$(sysctl hw.memsize | awk '{print $2/1024/1024/1024}')
            cpu_cores=$(sysctl -n hw.ncpu)
            ;;
        "Linux")
            total_memory_gb=$(free -g | awk '/^Mem:/{print $2}')
            cpu_cores=$(nproc)
            ;;
    esac
    
    if (( $(echo "$total_memory_gb < $MIN_MEMORY_GB" | bc -l) )); then
        log_error "Insufficient memory: ${total_memory_gb}GB available, ${MIN_MEMORY_GB}GB required"
        return 1
    fi
    
    if [ "$cpu_cores" -lt "$MIN_CPU_CORES" ]; then
        log_error "Insufficient CPU cores: ${cpu_cores} available, ${MIN_CPU_CORES} required"
        return 1
    fi
}

# Check required ports
check_ports() {
    for port in "${REQUIRED_PORTS[@]}"; do
        if lsof -i ":$port" >/dev/null 2>&1; then
            log_error "Port $port is already in use"
            return 1
        fi
    done
}

# Validate Docker Compose file
validate_compose_file() {
    local compose_file="config/dev/docker-compose.yml"
    if [ ! -f "$compose_file" ]; then
        log_error "Docker Compose file not found: $compose_file"
        return 1
    fi
    
    if ! docker compose -f "$compose_file" config >/dev/null 2>&1; then
        log_error "Invalid Docker Compose file"
        return 1
    fi
}

# Check environment variables
check_env_vars() {
    local env_file="config/dev/.env.dev"
    if [ ! -f "$env_file" ]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi
    
    # Check for required variables
    local required_vars=(
        "GO_ENV"
        "CGO_ENABLED"
        "GO111MODULE"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$env_file"; then
            log_error "Required environment variable missing: $var"
            return 1
        fi
    done
}

# Cleanup stale resources
cleanup_stale_resources() {
    # Remove stopped containers
    docker container prune -f >/dev/null 2>&1
    
    # Remove unused volumes
    docker volume prune -f >/dev/null 2>&1
    
    # Remove unused networks
    docker network prune -f >/dev/null 2>&1
    
    # Remove dangling images
    docker image prune -f >/dev/null 2>&1
}

# Main execution
main() {
    [[ "$QUIET" == "false" ]] && log_info "Checking Docker environment..."
    
    # Run all checks
    if ! check_docker_environment ${QUIET:+--quiet}; then
        if ! install_docker; then
            log_error "Failed to install Docker"
            exit 1
        fi
        
        if ! start_docker_daemon; then
            log_error "Failed to start Docker daemon"
            exit 1
        fi
    fi
    
    # Additional checks
    check_docker_version || exit 1
    check_system_resources || exit 1
    check_ports || exit 1
    validate_compose_file || exit 1
    check_env_vars || exit 1
    
    # Cleanup
    cleanup_stale_resources
    
    # Install Docker Compose if needed
    if [[ "$NO_COMPOSE" != "true" ]]; then
        if ! command -v docker-compose &>/dev/null; then
            if ! install_docker_compose; then
                log_error "Failed to install Docker Compose"
                exit 1
            fi
        fi
    fi
    
    [[ "$QUIET" == "false" ]] && log_info "Docker environment is ready"
    exit 0
}

main "$@" 