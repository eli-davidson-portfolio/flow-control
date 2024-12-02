#!/bin/bash
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common/init.sh"

# Ensure swag is installed
if ! command -v swag &> /dev/null; then
    log_info "Installing swag..."
    go install github.com/swaggo/swag/cmd/swag@latest
fi

# Generate API documentation
log_info "Generating API documentation..."
swag init -g cmd/flowcontrol/main.go --parseDependency --parseInternal

# Build the application
log_info "Building application..."
CGO_ENABLED=1 go build -o flow-control ./cmd/flowcontrol

log_info "Build complete!"
  