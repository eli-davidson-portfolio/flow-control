#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source dependencies
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"

# Health check utilities
check_port_available() {
    local port=$1
    local service=${2:-"service"}
    
    log_step "Checking port $port ($service)"
    
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i ":$port" >/dev/null 2>&1; then
            log_error "Port $port is already in use"
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -an | grep "LISTEN" | grep -q ":$port "; then
            log_error "Port $port is already in use"
            return 1
        fi
    else
        log_warning "Neither lsof nor netstat available, skipping port check"
    fi
    
    log_success "Port $port is available"
    return 0
}

check_service_health() {
    local service=$1
    local url=$2
    local timeout=${3:-30}
    local interval=${4:-1}
    local attempts=$((timeout / interval))
    local count=0

    log_step "Checking health of $service at $url"
    show_progress 0 $attempts "Health check"

    while [ $count -lt $attempts ]; do
        local response
        response=$(curl -s "$url" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$response" ]; then
            if echo "$response" | jq -e '.status == "healthy"' >/dev/null 2>&1; then
                show_progress $attempts $attempts "Health check"
                log_success "$service is healthy"
                return 0
            fi
        fi
        count=$((count + 1))
        show_progress $count $attempts "Health check"
        sleep $interval
    done

    log_error "$service failed health check"
    return 1
}

check_resource_usage() {
    local warning_threshold=${1:-80}
    local critical_threshold=${2:-90}
    local issues=0

    log_step "Checking system resources"

    # Check CPU usage
    if command -v top >/dev/null 2>&1; then
        local cpu_usage
        if is_darwin; then
            cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | cut -d'%' -f1)
        else
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
        fi

        if [ "${cpu_usage%.*}" -gt "$critical_threshold" ]; then
            log_error "CPU usage is critical: ${cpu_usage}%"
            issues=$((issues + 1))
        elif [ "${cpu_usage%.*}" -gt "$warning_threshold" ]; then
            log_warning "CPU usage is high: ${cpu_usage}%"
        else
            log_success "CPU usage is normal: ${cpu_usage}%"
        fi
    fi

    # Check memory usage
    if command -v free >/dev/null 2>&1; then
        local mem_usage
        mem_usage=$(free | grep Mem | awk '{print ($3/$2 * 100)}')
        
        if [ "${mem_usage%.*}" -gt "$critical_threshold" ]; then
            log_error "Memory usage is critical: ${mem_usage}%"
            issues=$((issues + 1))
        elif [ "${mem_usage%.*}" -gt "$warning_threshold" ]; then
            log_warning "Memory usage is high: ${mem_usage}%"
        else
            log_success "Memory usage is normal: ${mem_usage}%"
        fi
    elif is_darwin; then
        local mem_usage
        mem_usage=$(vm_stat | awk '/Pages active/ {print $3}' | sed 's/\.//')
        local total_mem
        total_mem=$(sysctl hw.memsize | awk '{print $2}')
        local mem_percent=$((mem_usage * 4096 * 100 / total_mem))
        
        if [ "$mem_percent" -gt "$critical_threshold" ]; then
            log_error "Memory usage is critical: ${mem_percent}%"
            issues=$((issues + 1))
        elif [ "$mem_percent" -gt "$warning_threshold" ]; then
            log_warning "Memory usage is high: ${mem_percent}%"
        else
            log_success "Memory usage is normal: ${mem_percent}%"
        fi
    fi

    # Check disk usage
    if command -v df >/dev/null 2>&1; then
        local disk_usage
        disk_usage=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
        
        if [ "$disk_usage" -gt "$critical_threshold" ]; then
            log_error "Disk usage is critical: ${disk_usage}%"
            issues=$((issues + 1))
        elif [ "$disk_usage" -gt "$warning_threshold" ]; then
            log_warning "Disk usage is high: ${disk_usage}%"
        else
            log_success "Disk usage is normal: ${disk_usage}%"
        fi
    fi

    return $issues
}

check_docker_health() {
    local container=$1
    local timeout=${2:-30}
    local interval=${3:-1}
    local attempts=$((timeout / interval))
    local count=0

    log_step "Checking health of container $container"
    show_progress 0 $attempts "Container health"

    while [ $count -lt $attempts ]; do
        local status
        status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
        
        if [ "$status" = "healthy" ]; then
            show_progress $attempts $attempts "Container health"
            log_success "Container $container is healthy"
            return 0
        elif [ "$status" = "unhealthy" ]; then
            show_progress $attempts $attempts "Container health"
            log_error "Container $container is unhealthy"
            return 1
        fi
        
        count=$((count + 1))
        show_progress $count $attempts "Container health"
        sleep $interval
    done

    log_error "Container $container health check timed out"
    return 1
}

check_docker_resources() {
    local container=$1
    local warning_threshold=${2:-80}
    local critical_threshold=${3:-90}
    local issues=0

    log_step "Checking resources for container $container"

    # Check CPU usage
    local cpu_usage
    cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" "$container" | sed 's/%//')
    
    if [ "${cpu_usage%.*}" -gt "$critical_threshold" ]; then
        log_error "Container CPU usage is critical: ${cpu_usage}%"
        issues=$((issues + 1))
    elif [ "${cpu_usage%.*}" -gt "$warning_threshold" ]; then
        log_warning "Container CPU usage is high: ${cpu_usage}%"
    else
        log_success "Container CPU usage is normal: ${cpu_usage}%"
    fi

    # Check memory usage
    local mem_usage
    mem_usage=$(docker stats --no-stream --format "{{.MemPerc}}" "$container" | sed 's/%//')
    
    if [ "${mem_usage%.*}" -gt "$critical_threshold" ]; then
        log_error "Container memory usage is critical: ${mem_usage}%"
        issues=$((issues + 1))
    elif [ "${mem_usage%.*}" -gt "$warning_threshold" ]; then
        log_warning "Container memory usage is high: ${mem_usage}%"
    else
        log_success "Container memory usage is normal: ${mem_usage}%"
    fi

    return $issues
}

# Export functions
export -f check_port_available
export -f check_service_health
export -f check_resource_usage
export -f check_docker_health
export -f check_docker_resources