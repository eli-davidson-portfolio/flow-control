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
if [ -f "$PROJECT_ROOT/config/dev/.env.dev" ]; then
    source "$PROJECT_ROOT/config/dev/.env.dev"
fi

# Configuration
APP_PORT=${APP_PORT:-8080}
WEBHOOK_PORT=${WEBHOOK_PORT:-9001}
REQUIRED_SPACE=${REQUIRED_SPACE:-1024}  # MB
STATE_DIR="$PROJECT_ROOT/data"
LOG_DIR="$PROJECT_ROOT/logs"
BACKUP_DIR="$PROJECT_ROOT/backups"

# Get memory percentage
memory_percentage() {
    if is_darwin; then
        # macOS memory check
        vm_stat | awk '/Pages active/ {active=$3} /Pages inactive/ {inactive=$3} /Pages speculative/ {speculative=$3} /Pages wired/ {wired=$4} /Pages free/ {free=$3} END {total=active+inactive+speculative+wired+free; used=active+inactive+speculative+wired; print int(used/total*100)}'
    else
        # Linux memory check
        free | awk '/Mem:/ {print int($3/$2 * 100)}'
    fi
}

# Check Docker Desktop
check_docker_desktop() {
    log_header "Checking Docker Desktop"

    # If we're in the container or Docker is available, we're good
    if [ -n "$FLOW_CONTROL_CONTAINER" ] || docker info >/dev/null 2>&1; then
        log_success "Docker environment is ready"
        return 0
    fi

    # If we get here and we're not in a container, Docker isn't working
    log_error "Docker is not responding"
    log_info "Please start Docker Desktop and try again"
    return 1
}

# Check required ports
check_ports() {
    log_header "Checking required ports"
    local result=0

    # Function to kill process using a port
    kill_port_process() {
        local port=$1
        local pid
        
        log_info "→ Checking port $port (service)"
        
        if is_darwin; then
            pid=$(lsof -ti :$port)
        else
            pid=$(netstat -tulpn 2>/dev/null | grep ":$port" | awk '{print $7}' | cut -d'/' -f1)
        fi
        
        if [ -n "$pid" ]; then
            log_warning "Port $port is in use by PID $pid, killing process..."
            kill -9 $pid 2>/dev/null
            sleep 1
        fi
        
        # Verify port is now available
        if check_port_available "$port"; then
            log_success "Port $port is now available"
            return 0
        else
            log_error "Failed to free port $port"
            return 1
        fi
    }

    # Check and free application port
    kill_port_process "$APP_PORT"
    
    # Check and free webhook port
    kill_port_process "$WEBHOOK_PORT"

    return $result
}

# Verify state directory
verify_directories() {
    log_header "Verifying state directory"
    local result=0

    # Check directory existence
    for dir in "$STATE_DIR" "$LOG_DIR" "$BACKUP_DIR"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        fi
    done

    # Check write permissions
    for dir in "$STATE_DIR" "$LOG_DIR" "$BACKUP_DIR"; do
        if [ ! -w "$dir" ]; then
            log_error "No write permission: $dir"
            result=1
        else
            log_success "Directory verified: $(basename "$dir")"
        fi
    done

    return $result
}

# Check resource usage
check_resources() {
    log_header "Checking resource usage"
    local result=0

    # Check CPU usage
    local cpu_usage
    cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | cut -d% -f1)
    if [ "${cpu_usage%.*}" -gt 80 ]; then
        log_warning "High CPU usage: $cpu_usage%"
    else
        log_success "CPU usage is normal: $cpu_usage%"
    fi

    # Check memory usage
    local mem_usage
    mem_usage=$(memory_percentage)
    if [ "${mem_usage%.*}" -gt 80 ]; then
        log_warning "High memory usage: $mem_usage%"
    else
        log_success "Memory usage is normal: $mem_usage%"
    fi

    # Check disk usage
    local disk_usage
    disk_usage=$(df -h . | awk 'NR==2 {print $5}' | cut -d% -f1)
    if [ "$disk_usage" -gt 80 ]; then
        log_warning "High disk usage: $disk_usage%"
    else
        log_success "Disk usage is normal: $disk_usage%"
    fi

    return $result
}

# Verify development environment
verify_dev_environment() {
    local result=0

    # 1. Check Docker Desktop
    if ! check_docker_desktop; then
        log_error "Docker Desktop check failed"
        result=1
    fi

    # 2. Check required ports
    if ! check_ports; then
        log_error "Port check failed"
        result=1
    fi

    # 3. Verify directories
    if ! verify_directories; then
        log_error "Directory verification failed"
        result=1
    fi

    # 4. Check resource usage
    if ! check_resources; then
        log_warning "Resource usage check failed"
    fi

    # Show summary
    log_header "Verification Summary"
    if [ $result -eq 0 ]; then
        log_success "Development environment verification passed"
    else
        log_error "Development environment verification failed"
    fi

    return $result
}

# Run verification if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    verify_dev_environment
fi 