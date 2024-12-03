#!/usr/bin/env bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Logging utilities
log_error() {
    echo -e "${RED}${BOLD}ERROR:${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}${BOLD}WARNING:${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}${BOLD}SUCCESS:${NC} $1"
}

log_info() {
    echo -e "${BLUE}${BOLD}INFO:${NC} $1"
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${GRAY}${BOLD}DEBUG:${NC} $1" >&2
    fi
}

log_header() {
    echo -e "\n${MAGENTA}${BOLD}=== $1 ===${NC}\n"
}

log_step() {
    echo -e "${CYAN}${BOLD}→${NC} $1"
}

# Export functions
export -f log_error
export -f log_warning
export -f log_success
export -f log_info
export -f log_debug
export -f log_header
export -f log_step