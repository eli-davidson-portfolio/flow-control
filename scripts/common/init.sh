#!/bin/bash
# init.sh
#
# Purpose:
#   Common initialization script sourced by all Flow Control project scripts.
#   Provides shared functions, variables, and environment setup.
#
# Usage:
#   source ./scripts/common/init.sh
#
# Environment Variables Set:
#   FLOW_ROOT_DIR    Project root directory
#   FLOW_SCRIPTS_DIR Scripts directory
#   FLOW_CACHE_DIR   Cache directory for temporary files
#   FLOW_LOG_DIR     Directory for log files
#   FLOW_BUILD_DIR   Directory for build artifacts
#   FLOW_TEST_DIR    Directory for test artifacts
#   FLOW_DOCS_DIR    Directory for documentation
#
# Global Variables Set:
#   DOCKER_COMPOSE_FILE  Path to docker-compose.yml
#   GO_MOD_FILE         Path to go.mod
#   CONFIG_FILE         Path to project config
#   LOG_LEVEL           Current logging level

set -e

# Get script directories
FLOW_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLOW_ROOT_DIR="$(cd "${FLOW_SCRIPTS_DIR}/.." && pwd)"

# Set up directories
FLOW_CACHE_DIR="${HOME}/.cache/flow-control"
FLOW_LOG_DIR="${FLOW_ROOT_DIR}/logs"
FLOW_BUILD_DIR="${FLOW_ROOT_DIR}/build"
FLOW_TEST_DIR="${FLOW_ROOT_DIR}/test"
FLOW_DOCS_DIR="${FLOW_ROOT_DIR}/docs"

# Create required directories
mkdir -p "$FLOW_CACHE_DIR" "$FLOW_LOG_DIR" "$FLOW_BUILD_DIR" "$FLOW_TEST_DIR" "$FLOW_DOCS_DIR"

# Set up file paths
DOCKER_COMPOSE_FILE="${FLOW_ROOT_DIR}/docker-compose.yml"
GO_MOD_FILE="${FLOW_ROOT_DIR}/go.mod"
CONFIG_FILE="${FLOW_ROOT_DIR}/.flowcontrol/config.yml"

# Default configuration
LOG_LEVEL=${LOG_LEVEL:-"info"}
DOCKER_BUILDKIT=${DOCKER_BUILDKIT:-1}
COMPOSE_DOCKER_CLI_BUILD=${COMPOSE_DOCKER_CLI_BUILD:-1}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_debug() { [[ "$LOG_LEVEL" == "debug" ]] && echo -e "${BLUE}[DEBUG]${NC} $1" >&2; }
log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get Go version from go.mod
get_go_version() {
    if [[ -f "$GO_MOD_FILE" ]]; then
        grep '^go ' "$GO_MOD_FILE" | cut -d' ' -f2
    fi
}

# Function to cleanup temporary files
cleanup_temp() {
    local dir="$1"
    local max_age="$2"
    
    if [[ -d "$dir" ]]; then
        find "$dir" -type f -mtime +7 -delete
    fi
}

# Export environment variables
export FLOW_ROOT_DIR
export FLOW_SCRIPTS_DIR
export FLOW_CACHE_DIR
export FLOW_LOG_DIR
export FLOW_BUILD_DIR
export FLOW_TEST_DIR
export FLOW_DOCS_DIR
export DOCKER_BUILDKIT
export COMPOSE_DOCKER_CLI_BUILD

# Initialize environment
log_info "Initializing Flow Control environment..."

# Check Go version if go is installed
if command_exists go; then
    GO_VERSION=$(get_go_version)
    CURRENT_GO_VERSION=$(go version | awk '{print $3}' | sed s/go//)
    if [[ "$GO_VERSION" != "$CURRENT_GO_VERSION" ]]; then
        log_warn "Go version mismatch: required $GO_VERSION, found $CURRENT_GO_VERSION"
    fi
fi

# Cleanup old cache files on startup (files older than 7 days)
cleanup_temp "$FLOW_CACHE_DIR" "7"

log_info "Flow Control environment initialized at $FLOW_ROOT_DIR" 