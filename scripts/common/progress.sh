#!/usr/bin/env bash

# Check if we're running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash. Please run with bash $0" >&2
    exit 1
fi

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

# ShadowLab ASCII art
show_logo() {
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
    local sleep_duration=$(awk "BEGIN {print $duration/100}")
    
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

# Matrix-style rain effect
matrix_rain() {
    local duration=$1
    local end=$((SECONDS+duration))
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#$%^&*()"
    
    while [ $SECONDS -lt $end ]; do
        echo -ne "${GREEN}${chars:RANDOM%${#chars}:1}${NC}"
        sleep 0.01
    done
    echo
}

# Define all functions before exporting
declare -fx show_logo
declare -fx spinner
declare -fx progress_bar
declare -fx status_msg
declare -fx complete_task
declare -fx matrix_rain

# If script is being run directly, show demo
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_logo
    status_msg "Running demo..." "info"
    matrix_rain 2
    (sleep 5 &) && progress_bar 5
    complete_task "Demo complete!"
fi 