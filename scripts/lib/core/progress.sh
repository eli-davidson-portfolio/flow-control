#!/usr/bin/env bash

# Get terminal width
get_term_width() {
    local width
    if command -v tput >/dev/null 2>&1; then
        width=$(tput cols)
    else
        width=80
    fi
    echo "$width"
}

# Show progress bar
show_progress() {
    local current=$1
    local total=$2
    local prefix=${3:-"Progress"}
    local width
    width=$(get_term_width)
    local bar_size=$((width - 20))
    local progress=$((current * bar_size / total))
    local percentage=$((current * 100 / total))

    # Create the progress bar
    printf "\r%s [" "$prefix"
    for ((i = 0; i < bar_size; i++)); do
        if [ $i -lt $progress ]; then
            printf "="
        elif [ $i -eq $progress ]; then
            printf ">"
        else
            printf " "
        fi
    done
    printf "] %3d%%" "$percentage"

    # Print newline if complete
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Show spinner
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'

    while ps a | awk '{print $1}' | grep -q "$pid"; do
        local temp=${spinstr#?}
        printf "\r%s" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r"
}

# Show countdown
show_countdown() {
    local seconds=$1
    local message=${2:-"Starting in"}

    for ((i = seconds; i > 0; i--)); do
        printf "\r%s %d..." "$message" "$i"
        sleep 1
    done
    printf "\r%s\n" "Starting now!"
}

# Export functions
export -f get_term_width
export -f show_progress
export -f show_spinner
export -f show_countdown