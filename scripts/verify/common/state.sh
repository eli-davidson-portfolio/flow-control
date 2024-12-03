#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source dependencies
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"
source "$PROJECT_ROOT/scripts/lib/bridge/protocol.sh"

# State management utilities
verify_state_dir() {
    local state_dir=$1
    local required_space=${2:-1024} # MB

    log_step "Verifying state directory structure"

    # Check if directory exists
    if [ ! -d "$state_dir" ]; then
        log_info "Creating state directory: $state_dir"
        mkdir -p "$state_dir" || {
            log_error "Failed to create state directory"
            return 1
        }
    fi

    # Check write permissions
    if ! touch "$state_dir/.write_test" 2>/dev/null; then
        log_error "No write permission in state directory"
        return 1
    fi
    rm -f "$state_dir/.write_test"

    # Check available space
    local available_space
    if is_darwin; then
        available_space=$(df -m "$state_dir" | awk 'NR==2 {print $4}')
    else
        available_space=$(df -m --output=avail "$state_dir" | tail -n1)
    fi

    if [ "$available_space" -lt "$required_space" ]; then
        log_error "Insufficient space in state directory (${available_space}MB < ${required_space}MB)"
        return 1
    fi

    # Verify subdirectories
    local subdirs=("logs" "backups" "tmp")
    for dir in "${subdirs[@]}"; do
        local full_path="$state_dir/$dir"
        if [ ! -d "$full_path" ]; then
            mkdir -p "$full_path" || {
                log_error "Failed to create $dir directory"
                return 1
            }
        fi
        log_success "Directory verified: $dir"
    done

    log_success "State directory structure verified: $state_dir"
    return 0
}

verify_bridge_protocol() {
    log_step "Verifying bridge protocol"
    
    # Check SQLite database
    if ! init_bridge; then
        log_error "Failed to initialize bridge protocol"
        return 1
    fi

    # Test state operations
    local test_level=0
    local test_status=0
    local test_metadata='{"test": true, "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'

    # Save test state
    log_step "Testing state persistence"
    if ! save_test_state "$test_level" "$test_status" "$test_metadata"; then
        log_error "Failed to save test state"
        return 1
    fi

    # Retrieve test state
    log_step "Testing state retrieval"
    local retrieved_state
    retrieved_state=$(get_test_state "$test_level")
    if [ -z "$retrieved_state" ]; then
        log_error "Failed to retrieve test state"
        return 1
    fi

    # Verify state format
    if ! echo "$retrieved_state" | jq . >/dev/null 2>&1; then
        log_error "Invalid state format"
        return 1
    fi

    # Log test message
    log_step "Testing logging system"
    if ! log_test_message "$test_level" "Bridge protocol verification" "info"; then
        log_error "Failed to log test message"
        return 1
    fi

    log_success "Bridge protocol verified"
    return 0
}

verify_state_persistence() {
    local state_file=$1
    local test_data='{"timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'", "status": "verified"}'

    log_step "Testing state file persistence"

    # Test write
    if ! echo "$test_data" > "$state_file"; then
        log_error "Failed to write state file"
        return 1
    fi

    # Test read
    if ! [ -s "$state_file" ]; then
        log_error "State file is empty"
        return 1
    fi

    # Verify JSON format
    if ! jq . "$state_file" >/dev/null 2>&1; then
        log_error "Invalid JSON in state file"
        return 1
    fi

    # Verify file permissions
    local perms
    perms=$(stat -f "%A" "$state_file" 2>/dev/null || stat -c "%a" "$state_file" 2>/dev/null)
    if [ "$perms" != "644" ]; then
        log_warning "Unexpected file permissions: $perms (expected 644)"
        chmod 644 "$state_file" || {
            log_error "Failed to set file permissions"
            return 1
        }
    fi

    log_success "State persistence verified"
    return 0
}

backup_state() {
    local source_dir=$1
    local backup_dir=$2
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    log_step "Creating state backup"

    # Create backup directory
    mkdir -p "$backup_dir" || {
        log_error "Failed to create backup directory"
        return 1
    }

    # Create backup
    local backup_file="$backup_dir/state_${timestamp}.tar.gz"
    if ! tar -czf "$backup_file" -C "$(dirname "$source_dir")" "$(basename "$source_dir")" 2>/dev/null; then
        log_error "Failed to create backup"
        return 1
    fi

    # Verify backup
    if ! [ -s "$backup_file" ]; then
        log_error "Backup file is empty"
        return 1
    fi

    # Verify backup integrity
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        log_error "Backup file is corrupted"
        rm -f "$backup_file"
        return 1
    fi

    log_success "State backed up to: $backup_file"
    return 0
}

restore_state() {
    local backup_file=$1
    local target_dir=$2

    log_step "Restoring state from backup"

    # Verify backup file
    if ! [ -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Verify backup integrity
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        log_error "Backup file is corrupted"
        return 1
    fi

    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)

    # Extract backup
    if ! tar -xzf "$backup_file" -C "$temp_dir" 2>/dev/null; then
        log_error "Failed to extract backup"
        rm -rf "$temp_dir"
        return 1
    fi

    # Verify extracted contents
    if ! [ -d "$temp_dir/$(basename "$target_dir")" ]; then
        log_error "Invalid backup structure"
        rm -rf "$temp_dir"
        return 1
    fi

    # Move to target directory
    rm -rf "$target_dir"
    if ! mv "$temp_dir"/* "$target_dir" 2>/dev/null; then
        log_error "Failed to restore state"
        rm -rf "$temp_dir"
        return 1
    fi

    rm -rf "$temp_dir"
    log_success "State restored from: $backup_file"
    return 0
}

# Export functions
export -f verify_state_dir
export -f verify_bridge_protocol
export -f verify_state_persistence
export -f backup_state
export -f restore_state