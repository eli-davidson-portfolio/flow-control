#!/bin/bash
# docker-check.sh
#
# Purpose:
#   Ensures Docker environment is ready and running.
#   This script will not fall back to local execution - Docker is required.
#   If Docker is not installed or not running, it will attempt to fix the situation.
#
# Usage:
#   ./docker-check.sh [options]
#
# Options:
#   --quiet         Suppress non-essential output
#   --no-compose    Skip Docker Compose checks
#
# Exit Codes:
#   0 - Docker environment is ready
#   1 - Fatal error occurred
#   2 - Docker installation failed
#   3 - Docker startup failed
#   4 - Resource constraints

set -e

# Script configuration
CACHE_DIR="${HOME}/.cache/flow-control"
CACHE_DURATION=300 # 5 minutes
DOCKER_MIN_VERSION="20.10.0"
COMPOSE_MIN_VERSION="2.0.0"
DOCKER_MIN_SPACE=10 # GB

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
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_debug() { [[ "$QUIET" == "false" ]] && echo -e "${BLUE}[DEBUG]${NC} $1" >&2; }
log_info() { [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Function to install Docker
install_docker() {
    log_info "Installing Docker..."
    case "$(uname)" in
        Darwin)
            if command -v brew &>/dev/null; then
                brew install --cask docker
            else
                log_error "Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
                return 1
            fi
            ;;
        Linux)
            if command -v apt-get &>/dev/null; then
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                sudo usermod -aG docker "$USER"
                rm get-docker.sh
            elif command -v dnf &>/dev/null; then
                sudo dnf -y install docker
                sudo systemctl enable docker
                sudo usermod -aG docker "$USER"
            else
                log_error "Unsupported Linux distribution"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported operating system"
            return 1
            ;;
    esac
    return 0
}

# Function to install Docker Compose
install_docker_compose() {
    log_info "Installing Docker Compose..."
    case "$(uname)" in
        Darwin)
            if command -v brew &>/dev/null; then
                brew install docker-compose
            else
                log_error "Please install Docker Compose manually"
                return 1
            fi
            ;;
        Linux)
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
            sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            ;;
        *)
            log_error "Unsupported operating system"
            return 1
            ;;
    esac
    return 0
}

# Function to start Docker daemon
start_docker() {
    log_info "Starting Docker daemon..."
    case "$(uname)" in
        Darwin)
            log_info "Starting Docker Desktop..."
            open -a Docker
            # Start Docker.app in background and don't wait
            (open -a Docker && sleep 1) &
            ;;
        Linux)
            if command -v systemctl &>/dev/null; then
                sudo systemctl start docker &
            else
                sudo service docker start &
            fi
            ;;
        *)
            log_error "Unsupported operating system"
            return 1
            ;;
    esac
    
    # Don't wait - return immediately
    return 0
}

# Function to check Docker installation
ensure_docker() {
    if ! command -v docker &>/dev/null; then
        log_warn "Docker not found, attempting to install..."
        if ! install_docker; then
            log_error "Failed to install Docker"
            log_error "If you see Go version mismatch errors, it's because Docker isn't properly installed"
            log_error "Please install Docker manually and try again"
            return 2
        fi
    fi
    
    # Start Docker daemon in background if not running
    if ! docker info &>/dev/null; then
        log_warn "Docker daemon not running"
        if ! start_docker; then
            log_error "Failed to start Docker daemon"
            log_error "If you see Go version mismatch errors, it's because Docker isn't running"
            log_error "Please start Docker manually and try again"
            return 3
        fi
    fi
    
    return 0
}

# Function to ensure Docker Compose
ensure_docker_compose() {
    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        log_warn "Docker Compose not found, attempting to install..."
        if ! install_docker_compose; then
            log_error "Failed to install Docker Compose"
            return 1
        fi
    fi
    return 0
}

# Function to check disk space
check_disk_space() {
    local docker_root
    if docker info 2>/dev/null | grep -q "Docker Root Dir"; then
        docker_root=$(docker info 2>/dev/null | grep "Docker Root Dir" | cut -d: -f2 | tr -d '[:space:]')
    else
        docker_root="/var/lib/docker"
    fi
    
    local available_space
    if [[ "$(uname)" == "Darwin" ]]; then
        available_space=$(df -g "$docker_root" | awk 'NR==2 {print $4}')
    else
        available_space=$(df -BG "$docker_root" | awk 'NR==2 {print $4}' | tr -d 'G')
    fi
    
    if (( available_space < DOCKER_MIN_SPACE )); then
        log_warn "Low disk space. Available: ${available_space}GB, Required: ${DOCKER_MIN_SPACE}GB"
        log_info "Running cleanup..."
        docker system prune -f --volumes
        return 4
    fi
    return 0
}

# Main execution
main() {
    log_info "Ensuring Docker environment..."
    
    # Ensure Docker is installed and running (async)
    ensure_docker || {
        log_error "Failed to ensure Docker environment"
        exit $?
    }
    
    # Check disk space
    check_disk_space || {
        log_error "Insufficient disk space"
        exit $?
    }
    
    # Ensure Docker Compose if needed
    if [[ "$NO_COMPOSE" != "true" ]]; then
        ensure_docker_compose || {
            log_error "Failed to ensure Docker Compose"
            exit $?
        }
    fi
    
    log_info "Docker environment is ready"
    return 0
}

main "$@" 