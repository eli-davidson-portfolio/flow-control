#!/bin/bash

# Check if we're running in the correct container
if [ -z "$FLOW_CONTROL_CONTAINER" ]; then
    echo "Error: This script must be run inside the flow-control container"
    echo "Please use: docker compose up dev"
    exit 1
fi

# Source our configuration
source "$(dirname "$0")/lib/core/config.sh"

log_info "Starting development servers..."

# Generate API documentation
if command -v swag &> /dev/null; then
    log_info "Generating API documentation..."
    swag init -g cmd/flowcontrol/main.go --parseDependency --parseInternal
fi

# Start the main API server with hot reload
if command -v air &> /dev/null; then
    log_info "Starting API server with hot reload..."
    air -c .air.toml &
else
    log_info "Starting API server..."
    go run cmd/flowcontrol/main.go &
fi

# Give servers a moment to start
sleep 2

# Return success
exit 0 