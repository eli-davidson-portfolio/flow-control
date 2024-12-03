#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set error handling
set -e

# Setup directories
FLOW_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLOW_SCRIPTS_DIR="${FLOW_ROOT_DIR}/scripts"
FLOW_LOG_DIR="${FLOW_ROOT_DIR}/logs"

# Create required directories
mkdir -p "${FLOW_LOG_DIR}"

# Change to workspace root directory
cd "${FLOW_ROOT_DIR}"

# Logging functions
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1" >&2; }
log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Ensure required commands are available
command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed."; exit 1; }
command -v docker compose >/dev/null 2>&1 || { log_error "Docker Compose is required but not installed."; exit 1; }

# Function to check if a port is available
check_port() {
  local port=$1
  if lsof -i ":$port" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# Function to get environment-specific host
get_host() {
  local env=${1:-dev}
  case $env in
    dev)
      echo "localhost"
      ;;
    staging)
      if [ -n "$STAGING_HOST" ]; then
        echo "$STAGING_HOST"
      else
        echo "localhost"
      fi
      ;;
    prod)
      if [ -n "$PROD_DOMAIN" ]; then
        echo "$PROD_DOMAIN"
      else
        echo "$PROD_HOST"
      fi
      ;;
    *)
      echo "localhost"
      ;;
  esac
}

# Function to get timestamp
get_timestamp() {
  date '+%Y%m%d_%H%M%S'
}

# Function to capture container logs
capture_logs() {
  local timestamp
  timestamp=$(get_timestamp)
  local log_dir="${FLOW_LOG_DIR}/deploy-${timestamp}"
  mkdir -p "${log_dir}"
  
  docker compose logs --no-color > "${log_dir}/containers.log" 2>&1
  echo "${log_dir}/containers.log"
}

# Export functions and variables
export FLOW_ROOT_DIR
export FLOW_SCRIPTS_DIR
export FLOW_LOG_DIR
export -f check_port
export -f get_host
export -f get_timestamp
export -f capture_logs
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error