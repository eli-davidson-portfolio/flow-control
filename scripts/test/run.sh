#!/bin/bash
set -e

# Set environment variables
export CGO_ENABLED=1
export CGO_CFLAGS='-D_FILE_OFFSET_BITS=64'

# Run setup if needed
if [ "$1" = "--setup" ]; then
    /app/scripts/test/setup.sh
    shift
fi

# If a package is specified, test only that package
if [ -n "$1" ]; then
    echo "Testing package $1..."
    go test -v "$1"
else
    echo "Testing all packages..."
    go test -v ./... 