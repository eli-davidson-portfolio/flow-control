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

# Determine script locations
FLOW_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLOW_ROOT_DIR="$(cd "$FLOW_SCRIPTS_DIR/.." && pwd)"

# Set up directory structure
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

# Function to check if we're running in CI
is_ci() {
    [[ -n "${CI:-}" ]]
}

# Function to check if we're running in Docker
is_docker() {
    [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# Function to get the Go version from go.mod
get_go_version() {
    if [[ -f "$GO_MOD_FILE" ]]; then
        grep "^go " "$GO_MOD_FILE" | cut -d' ' -f2
    else
        echo "1.22.9" # Default version if go.mod doesn't exist
    fi
}

# Function to check if Docker is available
check_docker() {
    if ! command_exists docker; then
        log_error "Docker is not installed"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    return 0
}

# Function to check if Docker Compose is available
check_docker_compose() {
    if command_exists docker-compose; then
        return 0
    elif docker compose version >/dev/null 2>&1; then
        return 0
    else
        log_error "Docker Compose is not installed"
        return 1
    fi
}

# Function to run a command with retries
retry() {
    local retries=${1:-3}
    local delay=${2:-5}
    shift 2
    
    local count=0
    until "$@"; do
        exit=$?
        count=$((count + 1))
        
        if [[ $count -lt $retries ]]; then
            log_warn "Command failed (attempt $count/$retries). Retrying in ${delay}s..."
            sleep "$delay"
        else
            log_error "Command failed after $count attempts"
            return $exit
        fi
    done
    return 0
}

# Function to get absolute path
get_abs_path() {
    local path="$1"
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd)
    elif [[ -f "$path" ]]; then
        if [[ $path == /* ]]; then
            echo "$path"
        else
            echo "$PWD/${path#./}"
        fi
    fi
}

# Function to cleanup temporary files older than specified days
cleanup_temp() {
    local dir="$1"
    local max_age="$2"
    
    if [[ -d "$dir" ]]; then
        find "$dir" -type f -mtime +7 -delete
    fi
}

# Ensure we're using the correct Go version
if command_exists go; then
    GO_VERSION=$(get_go_version)
    CURRENT_GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    if [[ "$CURRENT_GO_VERSION" != "$GO_VERSION" ]]; then
        log_warn "Current Go version ($CURRENT_GO_VERSION) doesn't match go.mod version ($GO_VERSION)"
    fi
fi

# Cleanup old cache files on startup (files older than 7 days)
cleanup_temp "$FLOW_CACHE_DIR" "7"

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

# Log initialization complete in debug mode
log_debug "Flow Control environment initialized at $FLOW_ROOT_DIR" 