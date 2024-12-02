#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAX_RETRIES=3
DOCKER_MIN_SPACE=10000000  # 10GB in KB
STARTUP_TIMEOUT=60

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check system requirements
check_system_requirements() {
    log_step "Checking system requirements..."
    
    # Check available disk space
    local available_space
    case "$(uname -s)" in
        Darwin)
            available_space=$(df -k / | awk 'NR==2 {print $4}')
            ;;
        Linux)
            available_space=$(df -k / | awk 'NR==2 {print $4}')
            ;;
    esac
    
    if [ "$available_space" -lt "$DOCKER_MIN_SPACE" ]; then
        log_error "Insufficient disk space. Need at least 10GB free."
        return 1
    fi
    
    # Check if running as root when needed
    if [ "$(uname -s)" = "Linux" ] && [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        log_error "Current user is not in docker group. Please run: sudo usermod -aG docker $USER"
        return 1
    fi
    
    log_info "System requirements met"
}

# Retry function for commands
retry_command() {
    local cmd="$1"
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if eval "$cmd"; then
            return 0
        fi
        retries=$((retries + 1))
        log_warn "Command failed, attempt $retries of $MAX_RETRIES"
        sleep 2
    done
    
    return 1
}

# Check if Docker is installed
check_docker_installed() {
    log_step "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        log_warn "Docker not found. Attempting to install..."
        if ! retry_command "install_docker"; then
            log_error "Failed to install Docker after $MAX_RETRIES attempts"
            return 1
        fi
    fi
    log_info "Docker is installed"
}

# Install Docker based on OS
install_docker() {
    case "$(uname -s)" in
        Darwin)
            if command -v brew &> /dev/null; then
                log_info "Installing Docker via Homebrew..."
                brew install --cask docker
            else
                log_error "Homebrew not found. Please install Docker Desktop manually from https://www.docker.com/products/docker-desktop"
                return 1
            fi
            ;;
        Linux)
            if command -v apt-get &> /dev/null; then
                log_info "Installing Docker via apt..."
                sudo apt-get update
                sudo apt-get install -y docker.io docker-compose
            elif command -v yum &> /dev/null; then
                log_info "Installing Docker via yum..."
                sudo yum install -y docker docker-compose
            else
                log_error "Unsupported Linux distribution. Please install Docker manually."
                return 1
            fi
            ;;
        *)
            log_error "Unsupported operating system. Please install Docker manually."
            return 1
            ;;
    esac
}

# Check if Docker daemon is running
check_docker_running() {
    log_step "Checking Docker daemon..."
    if ! docker info &> /dev/null; then
        log_warn "Docker daemon not running. Attempting to start..."
        if ! retry_command "start_docker"; then
            log_error "Failed to start Docker after $MAX_RETRIES attempts"
            return 1
        fi
    fi
    log_info "Docker daemon is running"
}

# Start Docker daemon based on OS
start_docker() {
    case "$(uname -s)" in
        Darwin)
            log_info "Starting Docker Desktop..."
            open -a Docker
            # Wait for Docker to start
            local timeout=$STARTUP_TIMEOUT
            while [ $timeout -gt 0 ]; do
                if docker info &> /dev/null; then
                    log_info "Docker Desktop started successfully"
                    return 0
                fi
                echo -n "."
                sleep 1
                timeout=$((timeout - 1))
            done
            log_error "Timeout waiting for Docker to start"
            return 1
            ;;
        Linux)
            log_info "Starting Docker daemon..."
            sudo systemctl start docker
            sudo systemctl enable docker
            ;;
        *)
            log_error "Unsupported operating system"
            return 1
            ;;
    esac
}

# Check Docker system resources
check_docker_resources() {
    log_step "Checking Docker resources..."
    local disk_usage
    disk_usage=$(docker system df 2>/dev/null | awk 'NR>1 {sum += $3} END {print sum}')
    
    if [ "$disk_usage" -gt 10000000000 ]; then  # 10GB
        log_warn "Docker is using significant disk space. Running cleanup..."
        if ! retry_command "docker_cleanup"; then
            log_error "Failed to clean up Docker resources"
            return 1
        fi
    fi
    log_info "Docker resources are healthy"
}

# Cleanup Docker resources
docker_cleanup() {
    log_info "Cleaning up Docker resources..."
    
    # Stop all containers gracefully
    if [ "$(docker ps -q)" ]; then
        docker stop $(docker ps -q) || true
    fi
    
    # Remove unused containers, networks, images, and volumes
    docker system prune -af --volumes
    
    # Verify cleanup
    local disk_usage
    disk_usage=$(docker system df 2>/dev/null | awk 'NR>1 {sum += $3} END {print sum}')
    if [ "$disk_usage" -gt 10000000000 ]; then
        log_warn "Docker is still using significant disk space after cleanup"
        return 1
    fi
    
    log_info "Docker cleanup complete"
}

# Check Docker Compose
check_docker_compose() {
    log_step "Checking Docker Compose..."
    if ! command -v docker compose &> /dev/null; then
        log_warn "Docker Compose not found. Attempting to install..."
        if ! retry_command "install_docker_compose"; then
            log_error "Failed to install Docker Compose"
            return 1
        fi
    fi
    log_info "Docker Compose is installed"
}

# Install Docker Compose
install_docker_compose() {
    case "$(uname -s)" in
        Darwin)
            # Docker Compose is included with Docker Desktop
            log_info "Docker Compose should be included with Docker Desktop"
            ;;
        Linux)
            log_info "Installing Docker Compose..."
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            ;;
    esac
}

# Verify Docker environment
verify_docker_environment() {
    log_step "Verifying Docker environment..."
    
    # Try to run a test container
    if ! docker run --rm hello-world &> /dev/null; then
        log_error "Failed to run test container"
        return 1
    fi
    
    # Check Docker API version compatibility
    local api_version
    api_version=$(docker version --format '{{.Server.APIVersion}}' 2>/dev/null)
    if [ -z "$api_version" ]; then
        log_error "Could not determine Docker API version"
        return 1
    fi
    
    log_info "Docker environment verified successfully"
}

# Main function to run all checks
ensure_docker_ready() {
    log_info "Preparing Docker environment..."
    
    # Run all checks
    check_system_requirements || return 1
    check_docker_installed || return 1
    check_docker_running || return 1
    check_docker_compose || return 1
    check_docker_resources || return 1
    verify_docker_environment || return 1
    
    log_info "Docker environment is ready"
}

# Run checks if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ensure_docker_ready
fi 