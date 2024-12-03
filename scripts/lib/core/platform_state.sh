#!/usr/bin/env bash

# Platform detection
is_darwin() {
    [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

is_windows() {
    [[ "$(uname -s)" == *"MINGW"* ]] || [[ "$(uname -s)" == *"MSYS"* ]]
}

# Architecture detection
is_arm64() {
    [[ "$(uname -m)" == "arm64" ]] || [[ "$(uname -m)" == "aarch64" ]]
}

is_x86_64() {
    [[ "$(uname -m)" == "x86_64" ]]
}

# Environment detection
is_ci() {
    [[ -n "${CI:-}" ]]
}

is_dev() {
    [[ "${ENVIRONMENT:-dev}" == "dev" ]]
}

is_staging() {
    [[ "${ENVIRONMENT:-dev}" == "staging" ]]
}

is_production() {
    [[ "${ENVIRONMENT:-dev}" == "production" ]]
}

# Docker detection
has_docker() {
    command -v docker >/dev/null 2>&1
}

has_docker_compose() {
    command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1
}

is_docker_running() {
    if is_darwin; then
        pgrep -f "Docker.app" >/dev/null
    else
        systemctl is-active --quiet docker
    fi
}

# Resource detection
get_cpu_count() {
    if is_darwin; then
        sysctl -n hw.ncpu
    else
        nproc
    fi
}

get_memory_mb() {
    if is_darwin; then
        echo $(($(sysctl -n hw.memsize) / 1024 / 1024))
    else
        free -m | awk '/^Mem:/{print $2}'
    fi
}

get_disk_free_mb() {
    local path=${1:-"/"}
    df -m "$path" | awk 'NR==2 {print $4}'
}

# Network detection
is_port_available() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        ! lsof -i ":$port" >/dev/null 2>&1
    elif command -v netstat >/dev/null 2>&1; then
        ! netstat -an | grep "LISTEN" | grep -q ":$port "
    else
        return 0  # Can't check, assume available
    fi
}

has_internet() {
    curl -s --connect-timeout 5 https://www.google.com >/dev/null
}

# Export functions
export -f is_darwin
export -f is_linux
export -f is_windows
export -f is_arm64
export -f is_x86_64
export -f is_ci
export -f is_dev
export -f is_staging
export -f is_production
export -f has_docker
export -f has_docker_compose
export -f is_docker_running
export -f get_cpu_count
export -f get_memory_mb
export -f get_disk_free_mb
export -f is_port_available
export -f has_internet