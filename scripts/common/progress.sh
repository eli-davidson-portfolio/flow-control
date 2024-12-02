#!/usr/bin/env bash

# Check if we're running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash. Please run with bash $0" >&2
    exit 1
fi

# Make functions available to subshells
set -a

# ANSI color codes
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Clear terminal and show ShadowLab ASCII art
show_logo() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
 ███████╗██╗  ██╗ █████╗ ██████╗  ██████╗ ██╗    ██╗██╗      █████╗ ██████╗ 
 ██╔════╝██║  ██║██╔══██╗██╔══██╗██╔═══██╗██║    ██║██║     ██╔══██╗██╔══██╗
 ███████╗███████║███████║██║  ██║██║   ██║██║ █╗ ██║██║     ███████║██████╔╝
 ╚════██║██╔══██║██╔══██║██║  ██║██║   ██║██║███╗██║██║     ██╔══██║██╔══██╗
 ███████║██║  ██║██║  ██║██████╔╝╚██████╔╝╚███╔███╔╝███████╗██║  ██║██████╔╝
 ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═════╝ 
EOF
    echo -e "${NC}"
}

# Spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⣾⣽⣻⢿⡿⣟⣯⣷'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Progress bar
progress_bar() {
    local duration=$1
    local width=50
    local progress=0
    local step=$((100/$width))
    
    echo -ne "\n"
    while [ $progress -le 100 ]; do
        echo -ne "\r[${CYAN}"
        for ((i=0; i<$width; i++)); do
            if [ $((progress/step)) -gt $i ]; then
                echo -ne "▰"
            else
                echo -ne "▱"
            fi
        done
        echo -ne "${NC}] ${progress}%"
        progress=$((progress+step))
        sleep 0.05
    done
    echo -ne "\n"
}

# Status messages with emojis
status_msg() {
    local msg=$1
    local status=$2
    case $status in
        "info")
            echo -e "${BLUE}[ℹ️ ]${NC} $msg"
            ;;
        "success")
            echo -e "${GREEN}[✅]${NC} $msg"
            ;;
        "warning")
            echo -e "${YELLOW}[⚠️ ]${NC} $msg"
            ;;
        "error")
            echo -e "${RED}[❌]${NC} $msg"
            ;;
    esac
}

# Task completion animation
complete_task() {
    local msg=$1
    echo -ne "${GREEN}"
    for i in {1..3}; do
        echo -ne "."
        sleep 0.5
    done
    echo -e " $msg${NC}"
}

# Turn off automatic exports
set +a

# If script is being run directly, show demo
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_logo
    status_msg "Running demo..." "info"
    (sleep 5 &) && progress_bar 5
    complete_task "Demo complete!"
fi 