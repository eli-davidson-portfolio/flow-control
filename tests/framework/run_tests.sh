#!/usr/bin/env bash

# Enable debug mode if requested
[[ "$TEST_DEBUG" == "1" ]] && set -x

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "$SCRIPT_DIR/../lib/core/config_base.sh"
source "$SCRIPT_DIR/../lib/core/logging.sh"
source "$SCRIPT_DIR/../lib/core/progress.sh"
source "$SCRIPT_DIR/../lib/core/platform_state.sh"
source "$SCRIPT_DIR/framework.sh"

# Test configuration
export TEST_MODE=true
export TEST_TIMEOUT=${TEST_TIMEOUT:-300}  # 5 minutes total timeout

# Test levels and their dependencies
declare -A TEST_LEVELS=(
    ["L0"]="L0_visual/visual_test.sh"
    ["L1"]="L1_core/platform_test.sh"
    ["L2"]="L2_environment/environment_test.sh"
)

declare -A TEST_DEPENDENCIES=(
    ["L0"]=""
    ["L1"]="L0"
    ["L2"]="L0 L1"
)

declare -A TEST_DESCRIPTIONS=(
    ["L0"]="Visual Elements"
    ["L1"]="Core Platform"
    ["L2"]="Environment"
)

# Attempt to recover system state
attempt_recovery() {
    local level="$1"
    local error_msg="$2"
    
    section_header "Recovery Attempt"
    status_msg "Attempting to recover from failure in level $level" "warning"
    
    case "$level" in
        L0)
            # Visual tests - no recovery needed
            status_msg "No recovery possible for visual test failures" "warning"
            return 1
            ;;
        L1)
            # Platform tests - check shell compatibility
            if ! is_shell "bash" && ! is_shell "zsh"; then
                status_msg "Attempting to switch to bash..." "info"
                if command -v bash >/dev/null 2>&1; then
                    status_msg "Please run tests with: bash $0" "info"
                else
                    status_msg "bash not found. Please install bash" "error"
                fi
            fi
            return 1
            ;;
        L2)
            # Environment tests - check Docker
            if is_platform "darwin"; then
                if ! is_docker_desktop_available; then
                    status_msg "Docker Desktop not running. Attempting to start..." "info"
                    if [[ -x "/Applications/Docker.app/Contents/MacOS/Docker" ]]; then
                        open -a Docker
                        
                        # Wait for Docker Desktop to start (max 60s)
                        local count=0
                        while ((count < 60)); do
                            status_msg "Waiting for Docker Desktop to start ($count/60s)..." "info"
                            if pgrep -f "Docker Desktop" >/dev/null; then
                                status_msg "Docker Desktop process started" "success"
                                
                                # Wait for Docker to be responsive
                                local ready_count=0
                                while ((ready_count < 30)); do
                                    if docker info >/dev/null 2>&1; then
                                        status_msg "Docker is now responsive" "success"
                                        return 0
                                    fi
                                    status_msg "Waiting for Docker to be responsive ($ready_count/30s)..." "info"
                                    sleep 1
                                    ((ready_count++))
                                done
                                
                                status_msg "Docker Desktop started but not responsive" "error"
                                return 1
                            fi
                            sleep 1
                            ((count++))
                        done
                        
                        status_msg "Docker Desktop failed to start" "error"
                        return 1
                    else
                        status_msg "Docker Desktop not found. Please install Docker Desktop" "error"
                        return 1
                    fi
                elif ! is_docker_available; then
                    status_msg "Docker Desktop running but not ready. Waiting..." "info"
                    
                    # Wait for Docker to be responsive
                    local count=0
                    while ((count < 30)); do
                        if docker info >/dev/null 2>&1; then
                            status_msg "Docker is now responsive" "success"
                            return 0
                        fi
                        status_msg "Waiting for Docker to be responsive ($count/30s)..." "info"
                        sleep 1
                        ((count++))
                    done
                    
                    status_msg "Docker Desktop not responding" "error"
                    return 1
                fi
            else
                if ! is_docker_available; then
                    status_msg "Docker daemon not running. Attempting to start..." "info"
                    if command -v systemctl >/dev/null 2>&1; then
                        sudo systemctl start docker
                        
                        # Wait for Docker to be responsive
                        local count=0
                        while ((count < 30)); do
                            if docker info >/dev/null 2>&1; then
                                status_msg "Docker daemon is now running" "success"
                                return 0
                            fi
                            status_msg "Waiting for Docker daemon ($count/30s)..." "info"
                            sleep 1
                            ((count++))
                        done
                        
                        status_msg "Docker daemon failed to start" "error"
                        return 1
                    else
                        status_msg "Cannot start Docker daemon. Please start manually" "error"
                        return 1
                    fi
                fi
            fi
            ;;
    esac
    
    return 1
}

# Run a single test level
run_test_level() {
    local level="$1"
    local script="$2"
    local full_path="${SCRIPT_DIR}/${script}"
    local desc="${TEST_DESCRIPTIONS[$level]}"
    local deps="${TEST_DEPENDENCIES[$level]}"
    local result=0
    
    # Check dependencies
    if [[ -n "$deps" ]]; then
        for dep in $deps; do
            if [[ "${LEVEL_STATUS[$dep]:-fail}" != "pass" ]]; then
                status_msg "Dependency $dep not satisfied for level $level" "error"
                LEVEL_STATUS[$level]="fail"
                return 1
            fi
        done
    fi
    
    # Check script exists
    if [[ ! -f "$full_path" ]]; then
        status_msg "Test script not found: $script" "error"
        LEVEL_STATUS[$level]="fail"
        return 1
    fi
    
    # Ensure script is executable
    if [[ ! -x "$full_path" ]]; then
        status_msg "Making test script executable: $script" "warning"
        chmod +x "$full_path" || {
            status_msg "Failed to make script executable: $script" "error"
            LEVEL_STATUS[$level]="fail"
            return 1
        }
    fi
    
    # Run tests with recovery attempts
    local max_attempts=3
    local attempt=1
    
    while ((attempt <= max_attempts)); do
        section_header "Level $level: $desc (Attempt $attempt/$max_attempts)"
        
        if "$full_path"; then
            status_msg "Level ${level} tests passed" "success"
            LEVEL_STATUS[$level]="pass"
            print_level_summary "$level"
            return 0
        else
            result=1
            print_level_summary "$level"
            
            if ((attempt < max_attempts)); then
                if attempt_recovery "$level" "$?"; then
                    status_msg "Recovery attempt $attempt succeeded. Retrying..." "info"
                    sleep 5  # Give system time to stabilize
                else
                    status_msg "Recovery attempt $attempt failed" "error"
                fi
            fi
        fi
        ((attempt++))
    done
    
    status_msg "Level ${level} tests failed after $max_attempts attempts" "error"
    LEVEL_STATUS[$level]="fail"
    return 1
}

# Run all test levels
run_all_tests() {
    local failed=0
    local passed=0
    local skipped=0
    local start_time=$SECONDS
    
    # Initialize test suite
    init_test_suite
    
    # Show logo first
    show_logo
    
    section_header "Test Environment"
    
    # Check Docker status first
    if is_platform "darwin"; then
        if ! is_docker_desktop_available; then
            status_msg "Docker Desktop is not running" "warning"
            if [[ -x "/Applications/Docker.app/Contents/MacOS/Docker" ]]; then
                status_msg "Starting Docker Desktop..." "info"
                open -a Docker
                sleep 5  # Give it time to start
            fi
        fi
    fi
    
    # Show environment info
    status_msg "Platform: $(get_platform_info os_type) $(get_platform_info os_version)"
    status_msg "Shell: $(get_platform_info shell_type) $(get_platform_info shell_version)"
    status_msg "Docker: $(is_docker_available && echo "Available" || echo "Not Available")"
    if is_platform "darwin"; then
        status_msg "Docker Desktop: $(is_docker_desktop_available && echo "Running" || echo "Not Running")"
    fi
    status_msg "Debug Mode: ${TEST_DEBUG:-0}"
    
    # Run tests in order
    local ordered_levels=(L0 L1 L2)
    for level in "${ordered_levels[@]}"; do
        if run_test_level "$level" "${TEST_LEVELS[$level]}"; then
            ((passed++))
        else
            ((failed++))
            # If L0 or L1 fails, stop testing
            if [[ "$level" =~ ^L[01]$ ]]; then
                status_msg "Critical test level failed. Stopping tests." "error"
                break
            fi
        fi
    done
    
    # Print final summary
    local duration=$((SECONDS - start_time))
    section_header "Final Test Summary"
    echo "Duration: ${duration}s"
    print_summary
    
    return $((failed > 0))
}

# Run with timeout if available
if command -v timeout >/dev/null 2>&1; then
    if ! timeout "$TEST_TIMEOUT" bash -c "$(declare -f); run_all_tests"; then
        if [[ $? -eq 124 ]]; then
            status_msg "Tests timed out after ${TEST_TIMEOUT} seconds" "error"
        fi
        exit 1
    fi
else
    # No timeout command available, run directly
    if ! run_all_tests; then
        exit 1
    fi
fi