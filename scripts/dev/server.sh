#!/bin/bash
set -e

# Install air if not present
if ! command -v air &> /dev/null; then
    echo "Installing air..."
    go install github.com/cosmtrek/air@latest
fi

# Install swag if not present
if ! command -v swag &> /dev/null; then
    echo "Installing swag..."
    go install github.com/swaggo/swag/cmd/swag@latest
fi

# Generate API documentation
echo "Generating API documentation..."
swag init -g cmd/flowcontrol/main.go --parseDependency --parseInternal

echo "Starting development server..."
air -c .air.toml 