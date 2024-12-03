#!/usr/bin/env bash

# Enable debug mode if requested
[[ "$TEST_DEBUG" == "1" ]] && set -x

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source dependencies
source "$TEST_ROOT/../lib/core/config_base.sh"
source "$TEST_ROOT/../lib/core/logging.sh"
source "$TEST_ROOT/../lib/core/progress.sh"
source "$TEST_ROOT/../lib/core/platform_state.sh"
source "$TEST_ROOT/../lib/config/docker_config.sh"
source "$TEST_ROOT/../lib/recovery/recovery_manager.sh"
source "$TEST_ROOT/framework.sh"

# Cleanup function to ensure no leftover containers
cleanup_test_environment() {
    local env_name="$1"
    log_info "Cleaning up test environment: $env_name"
    
    # List containers before cleanup
    log_info "Containers before cleanup:"
    docker ps -a --filter name="flow-control-${env_name}" --format "{{.Names}} ({{.Status}})"
    
    # Remove all test containers
    docker rm -f $(docker ps -aq --filter name="flow-control-${env_name}") >/dev/null 2>&1 || true
    
    # Verify cleanup
    if docker ps -aq --filter name="flow-control-${env_name}" | grep -q .; then
        log_error "Failed to clean up all test containers"
        return 1
    fi
    
    log_info "Environment cleaned successfully"
    return 0
}

# Test full deployment workflow
test_deployment_workflow() {
    local test_env="dev"
    cleanup_test_environment "$test_env" || return 1
    
    local network_name="flow-control-${test_env}"
    local services=("db" "cache" "api" "web")
    local result=0
    
    # Initialize recovery manager
    if ! init_recovery_manager "$network_name"; then
        log_error "Failed to initialize recovery manager"
        return 1
    fi
    
    # Register services with dependencies
    register_service "db"
    register_service "cache" "db"
    register_service "api" "cache"
    register_service "web" "api"
    
    # Start services
    for service in "${services[@]}"; do
        local container_name="flow-control-${test_env}-${service}"
        log_info "Creating $service service..."
        
        if ! docker run -d --name "$container_name" \
            --network "$network_name" \
            --health-cmd="exit 0" \
            --health-interval=1s \
            --health-retries=3 \
            --health-timeout=1s \
            --restart=unless-stopped \
            alpine sh -c 'while true; do sleep 1; done' >/dev/null 2>&1; then
            log_error "Failed to create $service service"
            cleanup_recovery_manager "$network_name"
            return 1
        fi
        
        # Wait for container to be healthy
        local timeout=10
        local healthy=0
        for ((i=0; i<timeout; i++)); do
            if docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null | grep -q "healthy"; then
                healthy=1
                log_info "Service $service is healthy"
                break
            fi
            sleep 1
        done
        
        if [[ $healthy -eq 0 ]]; then
            log_error "Service $service failed to become healthy"
            cleanup_recovery_manager "$network_name"
            return 1
        fi
    done
    
    # Verify all containers are running and healthy
    log_info "Verifying all services..."
    for service in "${services[@]}"; do
        local container_name="flow-control-${test_env}-${service}"
        if ! docker ps --filter "name=$container_name" --format '{{.Status}}' | grep -q "Up" || \
           ! docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null | grep -q "healthy"; then
            log_error "Container $container_name not running or not healthy"
            result=1
            break
        fi
        log_info "Container $container_name verified"
    done
    
    # Verify service communication
    if [[ $result -eq 0 ]]; then
        log_info "Verifying service communication..."
        for service in "${services[@]}"; do
            local container_name="flow-control-${test_env}-${service}"
            local deps="${SERVICE_DEPS[$service]}"
            
            if [[ -n "$deps" ]]; then
                for dep in $deps; do
                    local dep_container="flow-control-${test_env}-${dep}"
                    if ! docker exec "$container_name" ping -c 1 "$dep_container" >/dev/null 2>&1; then
                        log_error "Service $service cannot communicate with dependency $dep"
                        result=1
                        break 2
                    fi
                    log_info "Verified communication: $service -> $dep"
                done
            fi
        done
    fi
    
    # Cleanup
    cleanup_recovery_manager "$network_name"
    
    if [[ $result -eq 0 ]]; then
        log_info "Deployment workflow test passed successfully"
    else
        log_error "Deployment workflow test failed"
    fi
    
    cleanup_test_environment "$test_env"
    return $result
}

# Test cascading failure recovery
test_cascading_recovery() {
    local test_env="test"
    local result=0
    cleanup_test_environment "$test_env" || return 1
    
    # Initialize recovery manager
    if ! init_recovery_manager "flow-control-${test_env}"; then
        log_error "Failed to initialize recovery manager"
        return 1
    fi
    
    # Register services with dependencies
    register_service "db"
    register_service "cache" "db"
    register_service "api" "cache"
    register_service "web" "api"
    
    # Start all services
    log_info "Starting initial services..."
    for service in "db" "cache" "api" "web"; do
        local container_name="flow-control-${test_env}-${service}"
        if ! start_service "$service" "$container_name"; then
            log_error "Failed to start $service"
            cleanup_test_environment "$test_env"
            return 1
        fi
        SERVICE_CONTAINERS["$service"]="$container_name"
    done
    
    # Verify initial state
    log_info "Verifying initial state..."
    for service in "db" "cache" "api" "web"; do
        local container="flow-control-${test_env}-${service}"
        if ! docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null | grep -q "healthy"; then
            log_error "Service $service not healthy in initial state"
            cleanup_test_environment "$test_env"
            return 1
        fi
        log_info "Service $service is healthy in initial state"
    done
    
    # Test cascading failure recovery
    log_info "Testing cascading failure recovery..."
    log_info "Current container states:"
    docker ps --filter name="flow-control-${test_env}" --format "{{.Names}} ({{.Status}})"
    
    # Stop services in reverse order
    for service in "web" "api" "cache" "db"; do
        local container="flow-control-${test_env}-${service}"
        log_info "Stopping $container..."
        if ! docker stop "$container" >/dev/null 2>&1; then
            log_error "Failed to stop $container"
            result=1
            break
        fi
        sleep 2  # Give time for health checks to update
        log_info "Container states after stopping $service:"
        docker ps -a --filter name="flow-control-${test_env}" --format "{{.Names}} ({{.Status}})"
    done
    
    # Start recovery monitoring
    log_info "Starting recovery monitoring..."
    if ! monitor_services; then
        log_error "Recovery monitoring failed"
        result=1
    fi
    
    # Verify recovery
    log_info "Verifying recovery..."
    local -a recovered_services=()
    for service in "db" "cache" "api" "web"; do
        local container="flow-control-${test_env}-${service}"
        local status
        status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
        
        if [[ "$status" == "running" ]] && [[ "$health" == "healthy" ]]; then
            recovered_services+=("$service")
            log_info "Service $service recovered successfully (status=$status, health=$health)"
        else
            log_error "Service $service failed to recover (status=$status, health=$health)"
            result=1
        fi
    done
    
    # Verify recovery order matches dependencies
    if [[ ${#recovered_services[@]} -eq 4 ]]; then
        log_info "All services recovered. Verifying recovery order..."
        log_info "Recovery order was: ${RECOVERY_ORDER[*]}"
        
        # Verify each service was recovered after its dependencies
        for service in "${RECOVERY_ORDER[@]}"; do
            local deps="${SERVICE_DEPS[$service]}"
            if [[ -n "$deps" ]]; then
                for dep in $deps; do
                    local dep_index=-1
                    local service_index=-1
                    
                    # Find indices in recovery order
                    for ((i=0; i<${#RECOVERY_ORDER[@]}; i++)); do
                        if [[ "${RECOVERY_ORDER[$i]}" == "$dep" ]]; then
                            dep_index=$i
                        elif [[ "${RECOVERY_ORDER[$i]}" == "$service" ]]; then
                            service_index=$i
                        fi
                    done
                    
                    if [[ $dep_index -eq -1 ]]; then
                        log_error "Dependency $dep was not in recovery order"
                        result=1
                    elif [[ $service_index -eq -1 ]]; then
                        log_error "Service $service was not in recovery order"
                        result=1
                    elif [[ $dep_index -ge $service_index ]]; then
                        log_error "Service $service was recovered before its dependency $dep"
                        result=1
                    else
                        log_info "Service $service was correctly recovered after dependency $dep"
                    fi
                done
            fi
        done
        
        if [[ $result -eq 0 ]]; then
            log_info "Recovery order verification passed"
        fi
    else
        log_error "Not all services recovered (recovered: ${recovered_services[*]})"
        result=1
    fi
    
    # Final state check
    log_info "Final container states:"
    docker ps --filter name="flow-control-${test_env}" --format "{{.Names}} ({{.Status}})"
    
    cleanup_test_environment "$test_env"
    return $result
}

# Test resource handling
test_resource_handling() {
    local test_env="resource"
    cleanup_test_environment "$test_env" || return 1
    
    # Get current resource usage
    local cpu_usage
    local memory_usage
    
    cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" 2>/dev/null | sed 's/%//' | awk '{sum += $1} END {print sum}')
    memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" 2>/dev/null | awk '{print $1}')
    
    log_info "Resource usage - CPU: ${cpu_usage}%, Memory: ${memory_usage}"
    return 0
}

# Test network recovery
test_network_recovery() {
    local test_env="network"
    cleanup_test_environment "$test_env" || return 1
    
    log_info "Testing network partition..."
    
    # Create test network partition
    if docker network create test-partition >/dev/null 2>&1; then
        log_info "Network partition successful"
        docker network rm test-partition >/dev/null 2>&1
        return 0
    else
        log_error "Failed to create network partition"
        return 1
    fi
}

# Main test execution
main() {
    local result=0
    
    # Cleanup any leftover containers from previous runs
    log_info "Cleaning up previous test containers..."
    docker rm -f $(docker ps -a -q -f "name=flow-") >/dev/null 2>&1 || true
    docker network prune -f >/dev/null 2>&1
    
    # Initialize test suite
    init_test_suite
    
    # Start L4 tests
    if ! start_level 4 "Workflow Tests"; then
        log_error "Failed to start L4 tests"
        return 1
    fi
    
    # Run workflow tests
    run_test "Deployment Workflow" test_deployment_workflow || result=1
    run_test "Cascading Recovery" test_cascading_recovery || result=1
    run_test "Resource Handling" test_resource_handling || result=1
    run_test "Network Recovery" test_network_recovery || result=1
    
    # Complete level
    complete_level || result=1
    
    # Print results
    print_summary
    
    return $result
}

# Run tests if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 