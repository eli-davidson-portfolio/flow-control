#!/bin/bash
# fmt.sh
#
# Purpose:
#   Formats Go source code using gofmt and additional formatting tools.
#   Ensures consistent code style across the project.
#
# Usage:
#   ./fmt.sh [options]
#
# Options:
#   --check        Check if files are formatted without modifying (default: false)
#   --docker       Run formatter in Docker container (default: false)
#
# Environment Variables:
#   FMT_FLAGS      Additional flags to pass to gofmt

set -e

# Source common functions and variables
source "$(dirname "$0")/common/init.sh"

# Default configuration
FMT_FLAGS=${FMT_FLAGS:-"-s -w"}

# Parse command line arguments
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK_ONLY=true
            FMT_FLAGS="-d"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Execute formatting
if [[ "$CHECK_ONLY" == "true" ]]; then
    # Check mode - exit with error if any files need formatting
    if ! gofmt -l . | grep -q .; then
        exit 0
    else
        gofmt -d .
        exit 1
    fi
else
    # Format mode - modify files in place
    find . -name '*.go' -not -path "./vendor/*" -exec gofmt -s -w {} +
fi 