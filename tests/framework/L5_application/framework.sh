#!/bin/bash

# Source the main test framework
source "$(dirname "$0")/../framework.sh"

# Source L4 workflow functions we'll build upon
source "$(dirname "$0")/../L4_workflows/workflow_test.sh"

# Source Go test framework
source "$(dirname "$0")/framework_go.sh"

# Configuration
GO_SERVICE_NAME="flow-control"
GO_SERVICE_PORT=8080
GO_SERVICE_HEALTH_ENDPOINT="/health"
GO_SERVICE_CONFIG="/etc/flow-control/config.yaml"

# L5 specific setup
setup_l5_test() {
    log_info "Setting up L5 test environment"
    
    # Run Go tests first
    if ! setup_go_tests; then
        log_error "Failed to setup Go tests"
        return 1
    fi
    
    # Ensure L4 infrastructure is ready
    setup_workflow_test
    
    # Create service network if needed
    create_network_if_not_exists "flow-service"
    
    # Start Go service
    start_go_service
    
    # Wait for service health
    wait_for_service_health
    
    log_success "L5 test environment ready"
}

# L5 specific teardown
teardown_l5_test() {
    log_info "Tearing down L5 test environment"
    
    # Stop Go service
    stop_go_service
    
    # Clean up L4 infrastructure
    teardown_workflow_test
    
    # Clean up Go test artifacts
    cleanup_go_tests
    
    log_success "L5 test environment cleaned up"
}

# Go service management
start_go_service() {
    log_info "Starting Go service..."
    
    # Use built binary from Go tests
    docker run -d \
        --name "$GO_SERVICE_NAME" \
        --network flow-service \
        -p "$GO_SERVICE_PORT:$GO_SERVICE_PORT" \
        -v "$GO_SERVICE_CONFIG:/etc/flow-control/config.yaml" \
        -v "$(pwd)/bin/flow-control:/usr/local/bin/flow-control" \
        "$GO_SERVICE_NAME" flow-control
        
    # Verify container started
    if ! docker ps --filter "name=$GO_SERVICE_NAME" --format '{{.Names}}' | grep -q "^$GO_SERVICE_NAME$"; then
        log_error "Failed to start Go service"
        return 1
    fi
    
    log_success "Go service started"
}

stop_go_service() {
    log_info "Stopping Go service..."
    
    # Stop container gracefully
    docker stop "$GO_SERVICE_NAME" >/dev/null 2>&1
    
    # Remove container
    docker rm -f "$GO_SERVICE_NAME" >/dev/null 2>&1
    
    log_success "Go service stopped"
}

wait_for_service_health() {
    log_info "Waiting for service health check..."
    
    local retries=0
    local max_retries=30
    local endpoint="http://localhost:$GO_SERVICE_PORT$GO_SERVICE_HEALTH_ENDPOINT"
    
    while [ $retries -lt $max_retries ]; do
        if curl -s "$endpoint" | grep -q "healthy"; then
            log_success "Service is healthy"
            return 0
        fi
        retries=$((retries + 1))
        sleep 1
    done
    
    log_error "Service failed to become healthy"
    return 1
}

# Test helper functions
test_endpoint() {
    local endpoint=$1
    local expected_status=${2:-200}
    local method=${3:-GET}
    local data=${4:-""}
    
    log_info "Testing endpoint: $endpoint (expecting $expected_status)"
    
    local url="http://localhost:$GO_SERVICE_PORT$endpoint"
    local response
    local status
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "%{http_code}" "$url")
    else
        response=$(curl -s -w "%{http_code}" -X "$method" -d "$data" "$url")
    fi
    
    status=${response: -3}
    content=${response:0:${#response}-3}
    
    if [ "$status" -eq "$expected_status" ]; then
        log_success "Endpoint test passed"
        echo "$content"
        return 0
    else
        log_error "Endpoint test failed: got $status, expected $expected_status"
        return 1
    fi
}

verify_flow_state() {
    local flow_id=$1
    local expected_state=$2
    
    log_info "Verifying flow $flow_id state (expecting $expected_state)"
    
    local state
    state=$(test_endpoint "/flows/$flow_id/state")
    
    if [ "$?" -eq 0 ] && [ "$state" = "$expected_state" ]; then
        log_success "Flow state verified"
        return 0
    else
        log_error "Flow state mismatch: got $state, expected $expected_state"
        return 1
    fi
}

check_recovery() {
    local service_name=$1
    
    log_info "Checking recovery for $service_name"
    
    # Stop the service abruptly
    docker kill "$service_name" >/dev/null 2>&1
    
    # Wait for recovery
    local retries=0
    local max_retries=30
    
    while [ $retries -lt $max_retries ]; do
        if docker ps --filter "name=$service_name" --format '{{.Status}}' | grep -q "Up"; then
            log_success "Service recovered successfully"
            return 0
        fi
        retries=$((retries + 1))
        sleep 1
    done
    
    log_error "Service failed to recover"
    return 1
} 