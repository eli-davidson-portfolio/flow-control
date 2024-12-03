# Recovery Manager for Flow Control
# Handles automatic service recovery and dependency management

#!/bin/bash

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/logging.sh"
source "$SCRIPT_DIR/../core/progress.sh"
source "$SCRIPT_DIR/../core/platform_state.sh"

# Configuration
HEALTH_CHECK_INTERVAL=5  # seconds
MAX_RECOVERY_ATTEMPTS=3
RECOVERY_TIMEOUT=30      # seconds

# Track service dependencies
declare -A SERVICE_DEPS
declare -A SERVICE_HEALTH
declare -A RECOVERY_ATTEMPTS

# Initialize recovery manager
init_recovery_manager() {
    local network_name="$1"
    
    # Clean up any existing network
    if docker network ls | grep -q "$network_name"; then
        log_info "Removing existing network $network_name"
        docker network rm "$network_name" >/dev/null 2>&1 || true
    fi
    
    # Create network
    log_info "Creating network $network_name"
    if ! docker network create "$network_name" >/dev/null 2>&1; then
        log_error "Failed to create network $network_name"
        return 1
    fi
    
    # Store network name globally
    declare -g RECOVERY_NETWORK="$network_name"
    
    # Initialize service maps
    declare -g -A SERVICE_DEPS
    declare -g -A SERVICE_HEALTH
    declare -g -A SERVICE_CONTAINERS
    declare -g -a RECOVERY_ORDER
    
    log_info "Recovery manager initialized with network $network_name"
    return 0
}

# Register a service with its dependencies
register_service() {
    local service="$1"
    local depends_on="$2"
    
    SERVICE_DEPS["$service"]="$depends_on"
    SERVICE_HEALTH["$service"]="unknown"
    RECOVERY_ATTEMPTS["$service"]=0
    
    log_info "Registered service: $service (depends on: ${depends_on:-none})"
}

# Check if a service's dependencies are healthy
check_dependencies() {
    local service="$1"
    local deps="${SERVICE_DEPS[$service]}"
    
    if [[ -z "$deps" ]]; then
        return 0  # No dependencies
    fi
    
    for dep in $deps; do
        if [[ "${SERVICE_HEALTH[$dep]}" != "healthy" ]]; then
            return 1
        fi
    done
    
    return 0
}

# Update service health status
update_service_health() {
    local service="$1"
    local container_name="$2"
    local prev_health="${SERVICE_HEALTH[$service]}"
    
    if ! docker ps -q -f "name=$container_name" >/dev/null 2>&1; then
        SERVICE_HEALTH["$service"]="down"
    elif docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null | grep -q "healthy"; then
        SERVICE_HEALTH["$service"]="healthy"
    else
        SERVICE_HEALTH["$service"]="unhealthy"
    fi
    
    # Log health changes with more context
    if [[ "${SERVICE_HEALTH[$service]}" != "$prev_health" ]]; then
        local deps="${SERVICE_DEPS[$service]}"
        if [[ -n "$deps" ]]; then
            local dep_status=""
            for dep in $deps; do
                dep_status+="$dep:${SERVICE_HEALTH[$dep]} "
            done
            log_info "Service $service health changed: $prev_health -> ${SERVICE_HEALTH[$service]} (dependencies: $dep_status)"
        else
            log_info "Service $service health changed: $prev_health -> ${SERVICE_HEALTH[$service]} (no dependencies)"
        fi
    fi
}

# Attempt to recover a service
recover_service() {
    local service="$1"
    local container_name="$2"
    
    # Check recovery attempts
    if ((RECOVERY_ATTEMPTS["$service"] >= MAX_RECOVERY_ATTEMPTS)); then
        log_error "Max recovery attempts reached for $service"
        return 1
    fi
    
    # Check dependencies first
    if ! check_dependencies "$service"; then
        log_info "Waiting for dependencies of $service to recover first"
        return 1
    fi
    
    # Increment recovery attempts
    RECOVERY_ATTEMPTS["$service"]=$((RECOVERY_ATTEMPTS["$service"] + 1))
    
    # Stop container if it's running but unhealthy
    if docker ps -q -f "name=$container_name" >/dev/null 2>&1; then
        log_info "Stopping unhealthy container: $container_name"
        docker stop "$container_name" >/dev/null 2>&1 || true
        docker rm -f "$container_name" >/dev/null 2>&1 || true
    fi
    
    # Start container with health check
    log_info "Attempting to recover service: $service (attempt ${RECOVERY_ATTEMPTS[$service]})"
    
    if ! docker run -d --name "$container_name" \
        --network "$RECOVERY_NETWORK" \
        --health-cmd="exit 0" \
        --health-interval=1s \
        --health-retries=3 \
        --health-timeout=1s \
        --restart=unless-stopped \
        alpine sh -c 'while true; do sleep 1; done' >/dev/null 2>&1; then
        log_error "Failed to start container for $service"
        return 1
    fi
    
    # Wait for container to be healthy
    local timeout=10
    local healthy=0
    show_countdown "$timeout" "Waiting for $service to be healthy"
    
    for ((i=0; i<timeout; i++)); do
        local status
        status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
        log_info "Container $container_name health status: $status"
        
        if [[ "$status" == "healthy" ]]; then
            healthy=1
            break
        fi
        sleep 1
    done
    
    if [[ $healthy -eq 1 ]]; then
        log_info "Service $service recovered successfully"
        SERVICE_HEALTH["$service"]="healthy"
        RECOVERY_ATTEMPTS["$service"]=0  # Reset attempts on successful recovery
        return 0
    else
        log_error "Service $service failed to become healthy"
        return 1
    fi
}

# Start a service and wait for it to be healthy
start_service() {
    local service="$1"
    local container_name="$2"
    
    if [[ -z "$RECOVERY_NETWORK" ]]; then
        log_error "Recovery network not initialized"
        return 1
    fi
    
    log_info "Starting service $service ($container_name)..."
    
    # Check if container already exists
    if docker ps -a --filter "name=$container_name" --quiet | grep -q .; then
        log_info "Container $container_name already exists, removing..."
        docker rm -f "$container_name" >/dev/null 2>&1 || true
    fi
    
    # Start the container
    log_info "Creating container $container_name on network $RECOVERY_NETWORK"
    if ! docker run -d --name "$container_name" \
        --network "$RECOVERY_NETWORK" \
        --health-cmd="exit 0" \
        --health-interval=1s \
        --health-retries=3 \
        --health-timeout=1s \
        --restart=unless-stopped \
        alpine sh -c 'while true; do sleep 1; done' >/dev/null 2>&1; then
        log_error "Failed to create container $container_name"
        docker logs "$container_name" 2>&1 || true
        return 1
    fi
    
    # Verify container is running
    if ! docker ps --filter "name=$container_name" --quiet | grep -q .; then
        log_error "Container $container_name is not running"
        docker logs "$container_name" 2>&1 || true
        return 1
    fi
    
    # Wait for container to be healthy
    local timeout=10
    local healthy=0
    log_info "Waiting for $container_name to be healthy..."
    
    for ((i=0; i<timeout; i++)); do
        local status
        status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
        log_info "Container $container_name health status: $status"
        
        if [[ "$status" == "healthy" ]]; then
            healthy=1
            break
        fi
        sleep 1
    done
    
    if [[ $healthy -eq 0 ]]; then
        log_error "Container $container_name failed to become healthy within ${timeout}s"
        docker logs "$container_name" 2>&1 || true
        return 1
    fi
    
    log_info "Service $service ($container_name) started successfully"
    return 0
}

# Monitor and recover services
monitor_services() {
    local start_time=$SECONDS
    local recovered=0
    RECOVERY_ORDER=()
    local failed_services=()
    
    log_info "Starting recovery monitoring (timeout: ${RECOVERY_TIMEOUT}s)"
    log_info "Service dependencies:"
    for service in "${!SERVICE_DEPS[@]}"; do
        local deps="${SERVICE_DEPS[$service]}"
        log_info "  $service depends on: ${deps:-none}"
    done
    
    # Initial state logging
    log_info "Initial service states:"
    for service in "${!SERVICE_DEPS[@]}"; do
        local container_name="${SERVICE_CONTAINERS[$service]}"
        local status
        status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
        log_info "  $service: status=$status, health=$health"
        
        if [[ "$status" != "running" ]] || [[ "$health" != "healthy" ]]; then
            failed_services+=("$service")
        fi
    done
    
    log_info "Services requiring recovery: ${failed_services[*]}"
    
    # Recovery loop
    while ((SECONDS - start_time < RECOVERY_TIMEOUT)); do
        local all_healthy=1
        local remaining=$((RECOVERY_TIMEOUT - (SECONDS - start_time)))
        local status_summary=""
        local recovery_progress=0
        
        show_countdown "$remaining" "Monitoring services"
        
        # First, try to recover services without dependencies
        for service in "${!SERVICE_DEPS[@]}"; do
            if [[ -z "${SERVICE_DEPS[$service]}" ]]; then
                local container_name="${SERVICE_CONTAINERS[$service]}"
                local status
                status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
                local health
                health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
                
                if [[ "$status" != "running" ]] || [[ "$health" != "healthy" ]]; then
                    log_info "Attempting to recover independent service: $service"
                    if recover_service "$service" "$container_name"; then
                        RECOVERY_ORDER+=("$service")
                        recovery_progress=1
                    fi
                fi
            fi
        done
        
        # Then try to recover services with dependencies
        for service in "${!SERVICE_DEPS[@]}"; do
            if [[ -n "${SERVICE_DEPS[$service]}" ]]; then
                local container_name="${SERVICE_CONTAINERS[$service]}"
                local status
                status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
                local health
                health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
                
                if [[ "$status" != "running" ]] || [[ "$health" != "healthy" ]]; then
                    if check_dependencies "$service"; then
                        log_info "Attempting to recover dependent service: $service"
                        if recover_service "$service" "$container_name"; then
                            RECOVERY_ORDER+=("$service")
                            recovery_progress=1
                        fi
                    else
                        log_info "Waiting for dependencies before recovering $service"
                    fi
                fi
            fi
        done
        
        # Update and log status
        for service in "${!SERVICE_DEPS[@]}"; do
            local container_name="${SERVICE_CONTAINERS[$service]}"
            local status
            status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
            local health
            health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
            
            if [[ "$status" == "running" ]] && [[ "$health" == "healthy" ]]; then
                SERVICE_HEALTH["$service"]="healthy"
            else
                SERVICE_HEALTH["$service"]="unhealthy"
                all_healthy=0
            fi
            
            status_summary+="$service:${SERVICE_HEALTH[$service]} "
        done
        
        log_info "Current status: $status_summary"
        
        # Check if all services are healthy
        if [[ $all_healthy -eq 1 ]]; then
            recovered=1
            log_info "All services recovered successfully"
            log_info "Recovery order: ${RECOVERY_ORDER[*]}"
            log_info "Recovery completed in $((SECONDS - start_time))s"
            break
        fi
        
        # If no progress was made this iteration and we're not done, wait before retrying
        if [[ $recovery_progress -eq 0 ]]; then
            sleep "$HEALTH_CHECK_INTERVAL"
        fi
    done
    
    # Verify final state
    local all_recovered=1
    for service in "${!SERVICE_DEPS[@]}"; do
        local container_name="${SERVICE_CONTAINERS[$service]}"
        local status
        status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
        
        if [[ "$status" != "running" ]] || [[ "$health" != "healthy" ]]; then
            all_recovered=0
            log_error "Service $service failed to recover (status=$status, health=$health)"
        else
            log_info "Service $service recovered successfully (status=$status, health=$health)"
        fi
    done
    
    if [[ $all_recovered -eq 1 ]]; then
        log_info "Recovery verification passed"
        return 0
    else
        log_error "Recovery verification failed"
        return 1
    fi
}

# Cleanup recovery manager
cleanup_recovery_manager() {
    local network_name="$1"
    
    # Stop and remove all managed containers
    for service in "${!SERVICE_DEPS[@]}"; do
        local container_name="flow-test-$service"
        docker rm -f "$container_name" >/dev/null 2>&1 || true
    done
    
    # Remove recovery network
    docker network rm "$network_name" >/dev/null 2>&1 || true
    
    log_info "Recovery manager cleaned up"
} 