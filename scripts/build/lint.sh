#!/bin/bash
set -e

# Install golangci-lint if not present
if ! command -v golangci-lint &> /dev/null; then
    echo "Installing golangci-lint..."
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
fi

echo "Running linters..."
golangci-lint run 