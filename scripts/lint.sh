#!/bin/bash
# lint.sh
#
# Purpose:
#   Runs linting checks on the codebase using golangci-lint.
#   Ensures code quality and consistency with project standards.
#
# Usage:
#   ./lint.sh [options]
#
# Options:
#   --fix          Auto-fix issues where possible (default: false)
#   --docker       Run linter in Docker container (default: false)
#   --config       Path to custom golangci-lint config (default: .golangci.yml)
#
# Environment Variables:
#   LINT_FLAGS     Additional flags to pass to golangci-lint

set -e

# Source common functions and variables
source "$(dirname "$0")/common/init.sh"

# Default configuration
LINT_FLAGS=${LINT_FLAGS:-""}
CONFIG_FILE=".golangci.yml"

# Parse command line arguments
AUTO_FIX=false
DOCKER_LINT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            AUTO_FIX=true
            shift
            ;;
        --docker)
            DOCKER_LINT=true
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Add fix flag if requested
if [[ "$AUTO_FIX" == "true" ]]; then
    LINT_FLAGS="$LINT_FLAGS --fix"
fi

# Execute linting
if [[ "$DOCKER_LINT" == "true" ]]; then
    docker-compose run --rm lint
else
    golangci-lint run --config "$CONFIG_FILE" $LINT_FLAGS ./...
fi