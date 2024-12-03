#!/usr/bin/env bash

# Source dependencies
source "$(dirname "${BASH_SOURCE[0]}")/../lib/core/progress.sh"

# Demo function to simulate a long-running task
simulate_task() {
    local duration="$1"
    local step="$2"
    local i
    for ((i = 0; i <= duration; i += step)); do
        sleep "$step"
        echo "$i"
    done
}

# Main demo
main() {
    # Show logo
    show_logo
    
    # Section 1: Status Messages
    section_header "Status Message Demo"
    status_msg "Starting demo..." "info"
    sleep 0.5
    status_msg "This is a success message" "success"
    sleep 0.5
    status_msg "This is a warning message" "warning"
    sleep 0.5
    status_msg "This is an error message" "error"
    sleep 0.5
    
    # Section 2: Progress Bar
    section_header "Progress Bar Demo"
    status_msg "Demonstrating progress bar..."
    sleep 1
    
    local total=20
    local current=0
    while ((current < total)); do
        ((current++))
        progress_bar "$current" "$total" "Processing item $current of $total"
        sleep 0.1
    done
    
    # Section 3: Spinner
    section_header "Spinner Demo"
    status_msg "Demonstrating spinner..."
    sleep 0.5
    
    simulate_task 5 0.5 > /dev/null & 
    show_spinner "$!" "Running background task"
    wait "$!"
    status_msg "Background task complete" "success"
    
    # Section 4: Operation Tracking
    section_header "Operation Tracking Demo"
    
    # Start operation
    start_operation "demo-op"
    status_msg "Starting operation with retry logic..."
    sleep 0.5
    
    # Simulate failed attempts
    local attempt=1
    while check_max_attempts "demo-op"; do
        status_msg "Attempt $attempt..."
        sleep 0.5
        
        if ((attempt == 2)); then
            status_msg "Operation succeeded on attempt $attempt" "success"
            break
        fi
        
        status_msg "Attempt $attempt failed" "error"
        increment_attempt "demo-op"
        ((attempt++))
        sleep 1
    done
    
    # Final status
    section_header "Demo Complete"
    show_result "Progress System Demo" "true"
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 