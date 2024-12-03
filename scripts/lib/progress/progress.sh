#!/usr/bin/env bash

# Ensure we're running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash" >&2
    exit 1
fi

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Progress bar characters
PROGRESS_CHAR="▓"
EMPTY_CHAR="░"

# Function to show logo
show_logo() {
    cat << "EOF"
 _____ _                ____            _             _ 
|  ___| | _____      __/ ___|___  _ __ | |_ _ __ ___ | |
| |_  | |/ _ \ \ /\ / / |   / _ \| '_ \| __| '__/ _ \| |
|  _| | | (_) \ V  V /| |__| (_) | | | | |_| | | (_) | |_ 
|_|   |_|\___/ \_/\_/  \____\___/|_| |_|\__|_|  \___/ \__|
EOF
    echo
}

# Function to show status message with proper bash substitution
status_msg() {
    local message="$1"
    local type="${2:-info}"
    local color="$BLUE"
    local prefix
    
    case "$type" in
        success) 
            color="$GREEN"
            prefix="SUCCESS"
            ;;
        error) 
            color="$RED"
            prefix="ERROR"
            ;;
        warning) 
            color="$YELLOW"
            prefix="WARNING"
            ;;
        *) 
            color="$BLUE"
            prefix="INFO"
            ;;
    esac
    
    echo -e "${color}[${prefix}]${NC} ${message}"
}

# Function to show progress bar
progress_bar() {
    local duration=$1
    local width=50
    local interval=0.1
    local progress=0
    local steps=$((duration * 10))
    local step_size=$((width * 100 / steps))
    
    # Hide cursor
    tput civis
    
    while [ $progress -lt $steps ]; do
        local current=$((progress * step_size / 100))
        local rest=$((width - current))
        
        # Calculate percentage
        local percent=$((progress * 100 / steps))
        
        # Build progress bar
        printf "\r["
        printf "%${current}s" | tr ' ' "$PROGRESS_CHAR"
        printf "%${rest}s" | tr ' ' "$EMPTY_CHAR"
        printf "] %3d%%" $percent
        
        progress=$((progress + 1))
        sleep $interval
    done
    
    # Show cursor and move to next line
    tput cnorm
    echo
}

# Function to show spinner
show_spinner() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r[%c] %s" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r"
}

# Function to complete task
complete_task() {
    local message="$1"
    echo -e "\n${GREEN}✓${NC} $message"
}

# Function to show error
show_error() {
    local message="$1"
    echo -e "\n${RED}✗${NC} $message"
}

# Export functions and variables
export -f show_logo
export -f status_msg
export -f progress_bar
export -f show_spinner
export -f complete_task
export -f show_error

# Export color variables
export RED
export GREEN
export YELLOW
export BLUE
export MAGENTA
export CYAN
export NC 