#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source dependencies
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"
source "$PROJECT_ROOT/scripts/lib/core/platform_state.sh"
source "$PROJECT_ROOT/scripts/lib/bridge/protocol.sh"
source "$PROJECT_ROOT/scripts/verify/common/health.sh"
source "$PROJECT_ROOT/scripts/verify/common/state.sh"

# Load environment configuration
if [ -f "$PROJECT_ROOT/config/staging/.env.staging" ]; then
    source "$PROJECT_ROOT/config/staging/.env.staging"
fi

# Configuration
APP_PORT=${APP_PORT:-8080}
WEBHOOK_PORT=${WEBHOOK_PORT:-9001}
REQUIRED_SPACE=${REQUIRED_SPACE:-2048}  # MB
STATE_DIR=${STATE_DIR:-"/opt/flow-control/data"}
LOG_DIR=${LOG_DIR:-"/opt/flow-control/logs"}
BACKUP_DIR=${BACKUP_DIR:-"/opt/flow-control/backups"}

# Check Docker Engine
check_docker_engine() {
    log_header "Checking Docker Engine"

    # Check if Docker daemon is running
    if ! systemctl is-active --quiet docker; then
        log_error "Docker daemon is not running"
        return 1
    fi

    # Check Docker version
    local version
    version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    if [ -z "$version" ]; then
        log_error "Failed to get Docker version"
        return 1
    fi
    log_info "Docker version: $version"

    # Check if Docker daemon is responsive
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not responding"
        return 1
    fi

    # Check Docker Compose
    if ! has_docker_compose; then
        log_error "Docker Compose is not available"
        return 1
    fi

    # Verify Docker network
    if ! docker network ls | grep -q "flow-control"; then
        log_info "Creating Docker network: flow-control"
        if ! docker network create flow-control >/dev/null 2>&1; then
            log_error "Failed to create Docker network"
            return 1
        fi
    fi

    log_success "Docker Engine is running"
    return 0
}

# Check system resources
check_system_resources() {
    log_header "Checking system resources"
    local result=0

    # Check CPU cores
    local cpu_cores
    cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 2 ]; then
        log_warning "Low CPU cores available: $cpu_cores"
        result=1
    fi
    log_info "CPU cores: $cpu_cores"

    # Check memory
    local total_memory
    total_memory=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_memory" -lt 2048 ]; then
        log_warning "Low memory available: ${total_memory}MB"
        result=1
    fi
    log_info "Total memory: ${total_memory}MB"

    # Check disk space
    local disk_space
    disk_space=$(df -m "$STATE_DIR" | awk 'NR==2 {print $4}')
    if [ "$disk_space" -lt "$REQUIRED_SPACE" ]; then
        log_warning "Low disk space available: ${disk_space}MB"
        result=1
    fi
    log_info "Available disk space: ${disk_space}MB"

    return $result
}

# Check network configuration
check_network_config() {
    log_header "Checking network configuration"
    local result=0

    # Check if ports are accessible
    if ! check_port_available "$APP_PORT"; then
        log_error "Application port $APP_PORT is not available"
        result=1
    fi
    if ! check_port_available "$WEBHOOK_PORT"; then
        log_error "Webhook port $WEBHOOK_PORT is not available"
        result=1
    fi

    # Check external connectivity
    if ! has_internet; then
        log_error "No internet connection"
        result=1
    fi

    # Check DNS resolution
    if ! host -t A registry.hub.docker.com >/dev/null 2>&1; then
        log_error "DNS resolution failed"
        result=1
    fi

    return $result
}

# Check staging requirements
check_staging_requirements() {
    log_header "Checking staging requirements"
    local result=0

    # Check required commands
    local required_commands=("curl" "wget" "netstat" "systemctl" "journalctl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "$cmd is not installed"
            result=1
        else
            log_info "$cmd is available"
        fi
    done

    # Check system services
    local required_services=("docker" "sshd" "chronyd")
    for service in "${required_services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            log_error "$service service is not running"
            result=1
        else
            log_info "$service service is running"
        fi
    done

    return $result
}

# Verify staging environment
verify_staging_environment() {
    local result=0

    # Create required directories
    if ! mkdir -p "$STATE_DIR" "$LOG_DIR" "$BACKUP_DIR" 2>/dev/null; then
        log_error "Failed to create required directories"
        return 1
    fi

    # 1. Check staging requirements
    if ! check_staging_requirements; then
        log_error "Staging requirements check failed"
        result=1
    fi

    # 2. Check Docker Engine
    if ! check_docker_engine; then
        log_error "Docker Engine check failed"
        result=1
    fi

    # 3. Check system resources
    if ! check_system_resources; then
        log_warning "System resource check failed"
        result=1
    fi

    # 4. Check network configuration
    if ! check_network_config; then
        log_error "Network configuration check failed"
        result=1
    fi

    # 5. Verify state directory
    log_header "Verifying state directory"
    if ! verify_state_dir "$STATE_DIR" "$REQUIRED_SPACE"; then
        log_error "State directory verification failed"
        result=1
    fi

    # 6. Check resource usage
    log_header "Checking resource usage"
    if ! check_resource_usage 70 80; then
        log_warning "Resource usage is high"
    fi

    # 7. Verify bridge protocol
    log_header "Verifying bridge protocol"
    if ! verify_bridge_protocol; then
        log_error "Bridge protocol verification failed"
        result=1
    fi

    # 8. Test state persistence
    log_header "Testing state persistence"
    if ! verify_state_persistence "$STATE_DIR/staging_state.json"; then
        log_error "State persistence test failed"
        result=1
    fi

    # 9. Create state backup
    log_header "Creating state backup"
    if ! backup_state "$STATE_DIR" "$BACKUP_DIR"; then
        log_warning "State backup failed"
    fi

    # Show summary
    log_header "Verification Summary"
    if [ $result -eq 0 ]; then
        log_success "Staging environment verification passed"
    else
        log_error "Staging environment verification failed"
    fi

    return $result
}

# Run verification if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    verify_staging_environment
fi 