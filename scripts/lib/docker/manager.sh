#!/bin/bash
# Docker Manager Library
# Provides high-level Docker management with fault tolerance

# Ensure script directory is properly resolved
if [[ -z "$SCRIPT_DIR" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    if [[ ! -f "${SCRIPT_DIR}/lib/core/logging.sh" ]]; then
        echo "Error: Cannot find core libraries. SCRIPT_DIR=${SCRIPT_DIR}" >&2
        exit 1
    fi
fi

# Source dependencies
source "${SCRIPT_DIR}/lib/docker/docker.sh"
source "${SCRIPT_DIR}/lib/core/logging.sh"
source "${SCRIPT_DIR}/lib/core/config.sh"

# Initialize constants if not already set
if [[ -z "$CONTAINER_OK" ]]; then
    # Container status codes
    CONTAINER_OK=0
    CONTAINER_NOT_FOUND=1
    CONTAINER_START_ERROR=2
    CONTAINER_STOP_ERROR=3
    CONTAINER_HEALTH_ERROR=4
    
    # Container health check defaults
    HEALTH_CHECK_INTERVAL=5
    HEALTH_CHECK_TIMEOUT=30
    HEALTH_CHECK_RETRIES=3
    
    # Resource monitoring thresholds (percentage)
    CPU_WARNING_THRESHOLD=80
    CPU_CRITICAL_THRESHOLD=90
    
    # Export constants
    export CONTAINER_OK CONTAINER_NOT_FOUND CONTAINER_START_ERROR CONTAINER_STOP_ERROR CONTAINER_HEALTH_ERROR
    export HEALTH_CHECK_INTERVAL HEALTH_CHECK_TIMEOUT HEALTH_CHECK_RETRIES
    export CPU_WARNING_THRESHOLD CPU_CRITICAL_THRESHOLD
    
    # Make constants readonly
    readonly CONTAINER_OK CONTAINER_NOT_FOUND CONTAINER_START_ERROR CONTAINER_STOP_ERROR CONTAINER_HEALTH_ERROR
    readonly HEALTH_CHECK_INTERVAL HEALTH_CHECK_TIMEOUT HEALTH_CHECK_RETRIES
    readonly CPU_WARNING_THRESHOLD CPU_CRITICAL_THRESHOLD
fi

# Start a container with health checks and recovery
# Args:
#   $1 - Container name
#   $2 - Image name
#   $3 - Additional docker run arguments (optional)
start_container() {
    local container_name="$1"
    local image_name="$2"
    local extra_args="${3:-}"
    local start_time=$SECONDS
    
    log_info "Starting container ${container_name}..."
    
    # Ensure Docker is running
    ensure_docker_running || {
        log_error "Failed to ensure Docker is running"
        return $CONTAINER_START_ERROR
    }
    
    # Check if container already exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_info "Container ${container_name} already exists, removing..."
        docker rm -f "$container_name" >/dev/null 2>&1 || true
    fi
    
    # Start container with health check
    if ! docker run -d \
        --name "$container_name" \
        --health-cmd "curl -f http://localhost/ || exit 1" \
        --health-interval="${HEALTH_CHECK_INTERVAL}s" \
        --health-timeout="${HEALTH_CHECK_TIMEOUT}s" \
        --health-retries=$HEALTH_CHECK_RETRIES \
        $extra_args \
        "$image_name"; then
        log_error "Failed to start container ${container_name}"
        return $CONTAINER_START_ERROR
    fi
    
    # Wait for container to be healthy
    wait_for_container_health "$container_name" || {
        log_error "Container ${container_name} failed health check"
        collect_container_diagnostics "$container_name"
        return $CONTAINER_HEALTH_ERROR
    }
    
    log_info "Container ${container_name} started successfully"
    return $CONTAINER_OK
}

# Stop a container with graceful shutdown
# Args:
#   $1 - Container name
#   $2 - Timeout in seconds (optional)
stop_container() {
    local container_name="$1"
    local timeout="${2:-30}"
    
    log_info "Stopping container ${container_name}..."
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_warning "Container ${container_name} not found"
        return $CONTAINER_NOT_FOUND
    fi
    
    # Try graceful stop first
    if ! docker stop -t "$timeout" "$container_name" >/dev/null 2>&1; then
        log_warning "Failed to stop container ${container_name} gracefully, forcing..."
        if ! docker kill "$container_name" >/dev/null 2>&1; then
            log_error "Failed to force stop container ${container_name}"
            return $CONTAINER_STOP_ERROR
        fi
    fi
    
    # Remove the container
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    
    log_info "Container ${container_name} stopped successfully"
    return $CONTAINER_OK
}

# Monitor container health and resources
# Args:
#   $1 - Container name
monitor_container() {
    local container_name="$1"
    
    # Check if container exists
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_error "Container ${container_name} not found or not running"
        return $CONTAINER_NOT_FOUND
    fi
    
    # Check container health
    local health_status
    health_status=$(docker inspect --format '{{.State.Health.Status}}' "$container_name" 2>/dev/null)
    
    case "$health_status" in
        healthy)
            log_info "Container ${container_name} is healthy"
            ;;
        unhealthy)
            log_error "Container ${container_name} is unhealthy"
            collect_container_diagnostics "$container_name"
            return $CONTAINER_HEALTH_ERROR
            ;;
        *)
            log_warning "Container ${container_name} health status: ${health_status}"
            ;;
    esac
    
    # Check resource usage
    check_container_resources "$container_name" || {
        log_warning "Container ${container_name} resource usage is high"
        manage_container_resources "$container_name"
    }
    
    return $CONTAINER_OK
}

# Wait for container to be healthy
# Args:
#   $1 - Container name
#   $2 - Timeout in seconds (optional)
wait_for_container_health() {
    local container_name="$1"
    local timeout="${2:-$HEALTH_CHECK_TIMEOUT}"
    local start_time=$SECONDS
    
    while ((SECONDS - start_time < timeout)); do
        local health_status
        health_status=$(docker inspect --format '{{.State.Health.Status}}' "$container_name" 2>/dev/null)
        
        case "$health_status" in
            healthy)
                return $CONTAINER_OK
                ;;
            unhealthy)
                log_error "Container ${container_name} is unhealthy"
                return $CONTAINER_HEALTH_ERROR
                ;;
        esac
        
        sleep 1
    done
    
    log_error "Timeout waiting for container ${container_name} to be healthy"
    return $CONTAINER_HEALTH_ERROR
}

# Check container resource usage
# Args:
#   $1 - Container name
check_container_resources() {
    local container_name="$1"
    
    # Get CPU usage
    local cpu_usage
    cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" "$container_name" | sed 's/%//')
    
    # Get memory usage
    local memory_usage
    memory_usage=$(docker stats --no-stream --format "{{.MemPerc}}" "$container_name" | sed 's/%//')
    
    # Check CPU threshold
    if ((cpu_usage >= CPU_CRITICAL_THRESHOLD)); then
        log_error "Container ${container_name} CPU usage critical: ${cpu_usage}%"
        return 2
    elif ((cpu_usage >= CPU_WARNING_THRESHOLD)); then
        log_warning "Container ${container_name} CPU usage high: ${cpu_usage}%"
        return 1
    fi
    
    # Check memory threshold
    if ((memory_usage >= MEMORY_CRITICAL_THRESHOLD)); then
        log_error "Container ${container_name} memory usage critical: ${memory_usage}%"
        return 2
    elif ((memory_usage >= MEMORY_WARNING_THRESHOLD)); then
        log_warning "Container ${container_name} memory usage high: ${memory_usage}%"
        return 1
    fi
    
    return $CONTAINER_OK
}

# Manage container resources when usage is high
# Args:
#   $1 - Container name
manage_container_resources() {
    local container_name="$1"
    
    log_info "Managing resources for container ${container_name}..."
    
    # Get current resource limits
    local memory_limit
    memory_limit=$(docker inspect --format '{{.HostConfig.Memory}}' "$container_name")
    
    # If memory usage is critical, restart the container with higher limits
    if check_container_resources "$container_name" | grep -q "critical"; then
        log_warning "Restarting container ${container_name} with adjusted resources"
        
        # Stop the container
        stop_container "$container_name" || return $CONTAINER_STOP_ERROR
        
        # Get container configuration
        local image_name
        image_name=$(docker inspect --format '{{.Config.Image}}' "$container_name")
        
        # Calculate new memory limit (increase by 20%)
        local new_memory_limit=$((memory_limit * 120 / 100))
        
        # Restart with new limits
        docker run -d \
            --name "$container_name" \
            --memory "$new_memory_limit" \
            --health-cmd "curl -f http://localhost/ || exit 1" \
            --health-interval="${HEALTH_CHECK_INTERVAL}s" \
            --health-timeout="${HEALTH_CHECK_TIMEOUT}s" \
            --health-retries=$HEALTH_CHECK_RETRIES \
            "$image_name" || return $CONTAINER_START_ERROR
    fi
    
    return $CONTAINER_OK
}

# Collect container diagnostics
# Args:
#   $1 - Container name
collect_container_diagnostics() {
    local container_name="$1"
    local diag_file="${container_name}_diagnostics.log"
    
    log_info "Collecting diagnostics for container ${container_name}..."
    
    {
        echo "Container Diagnostics: ${container_name}"
        echo "=================================="
        echo "Timestamp: $(date)"
        echo
        
        echo "Container Info"
        echo "-------------"
        docker inspect "$container_name" 2>/dev/null || echo "Failed to get container info"
        echo
        
        echo "Container Logs"
        echo "--------------"
        docker logs --tail 100 "$container_name" 2>/dev/null || echo "Failed to get container logs"
        echo
        
        echo "Resource Usage"
        echo "--------------"
        docker stats --no-stream "$container_name" 2>/dev/null || echo "Failed to get resource usage"
        echo
        
        echo "Host System Status"
        echo "-----------------"
        if is_darwin; then
            top -l 1 -n 5 -stats pid,command,cpu,mem
        else
            top -b -n 1 | head -n 20
        fi
    } > "$diag_file"
    
    log_info "Diagnostics saved to ${diag_file}"
}

# Export functions
export -f start_container
export -f stop_container
export -f monitor_container
export -f wait_for_container_health
export -f check_container_resources
export -f manage_container_resources
export -f collect_container_diagnostics 