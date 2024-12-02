#!/bin/bash
set -e

# Install development tools
echo "Installing development tools..."

# Install swag
if ! command -v swag &> /dev/null; then
    echo "Installing swag..."
    go install github.com/swaggo/swag/cmd/swag@latest
fi

# Install golangci-lint
if ! command -v golangci-lint &> /dev/null; then
    echo "Installing golangci-lint..."
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
fi

# Install air
if ! command -v air &> /dev/null; then
    echo "Installing air..."
    go install github.com/cosmtrek/air@latest
fi

# Install git hooks
echo "Installing git hooks..."
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "Tools installation complete" 