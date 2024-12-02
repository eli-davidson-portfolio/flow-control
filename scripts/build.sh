#!/bin/bash
# build.sh
#
# Purpose:
#   Builds the Flow Control project, handling both local and Docker-based builds.
#   Ensures all dependencies are in place and compiles the project with proper flags.
#
# Usage:
#   ./build.sh [options]
#
# Options:
#   --docker     Build using Docker container (default: false)
#   --release    Build in release mode with optimizations (default: false)
#   --race       Enable race detection (default: false)
#
# Environment Variables:
#   BUILD_FLAGS  Additional build flags to pass to go build
#   GO_VERSION   Go version to use (default: from go.mod)
#   CGO_ENABLED  Enable/disable cgo (default: 1)

set -e

# Source common functions and variables
source "$(dirname "$0")/common/init.sh"

# Build configuration
BUILD_FLAGS=${BUILD_FLAGS:-""}
CGO_ENABLED=${CGO_ENABLED:-1}

# Parse command line arguments
DOCKER_BUILD=false
RELEASE_BUILD=false
RACE_DETECTION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --docker)
            DOCKER_BUILD=true
            shift
            ;;
        --release)
            RELEASE_BUILD=true
            shift
            ;;
        --race)
            RACE_DETECTION=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Add build flags based on options
if [[ "$RELEASE_BUILD" == "true" ]]; then
    BUILD_FLAGS="$BUILD_FLAGS -ldflags=-w -ldflags=-s"
fi

if [[ "$RACE_DETECTION" == "true" ]]; then
    BUILD_FLAGS="$BUILD_FLAGS -race"
fi

# Execute build
if [[ "$DOCKER_BUILD" == "true" ]]; then
    docker-compose run --rm build
else
    CGO_ENABLED=$CGO_ENABLED go build $BUILD_FLAGS ./...
  