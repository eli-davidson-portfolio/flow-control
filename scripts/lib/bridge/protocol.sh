#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source dependencies
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"

# Configuration
DB_FILE="$PROJECT_ROOT/data/test_state.db"
SCHEMA_FILE="$SCRIPT_DIR/schema.sql"

# Initialize bridge protocol
init_bridge() {
    log_info "Initializing bridge protocol"

    # Create data directory if it doesn't exist
    mkdir -p "$(dirname "$DB_FILE")"

    # Check if SQLite is available
    if ! command -v sqlite3 >/dev/null 2>&1; then
        log_error "SQLite3 is not installed"
        return 1
    fi

    # Create database if it doesn't exist
    if [ ! -f "$DB_FILE" ]; then
        log_info "Creating new database"
        if ! sqlite3 "$DB_FILE" < "$SCHEMA_FILE"; then
            log_error "Failed to create database"
            return 1
        fi
    fi

    # Verify database schema
    if ! verify_schema; then
        log_error "Database schema verification failed"
        return 1
    fi

    log_success "Bridge protocol initialized"
    return 0
}

# Verify database schema
verify_schema() {
    local expected_tables="test_logs test_results test_state"
    local actual_tables
    actual_tables=$(sqlite3 "$DB_FILE" ".tables" | tr -s ' ' '\n' | grep -v '^$' | sort | tr '\n' ' ' | sed 's/ $//')

    if [ "$actual_tables" != "$expected_tables" ]; then
        log_error "Schema mismatch. Expected: $expected_tables, Got: $actual_tables"
        return 1
    fi
    return 0
}

# Save test state
save_test_state() {
    local level=$1
    local status=$2
    local metadata=$3
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log_info "Saving test state for level $level"

    local query="INSERT OR REPLACE INTO test_state (level, status, metadata, timestamp) 
                 VALUES ($level, $status, '$metadata', '$timestamp');"

    if ! sqlite3 "$DB_FILE" "$query"; then
        log_error "Failed to save test state"
        return 1
    fi

    log_success "Test state saved"
    return 0
}

# Get test state
get_test_state() {
    local level=$1

    local query="SELECT json_object(
                   'level', level,
                   'status', status,
                   'metadata', metadata,
                   'timestamp', timestamp
                 )
                 FROM test_state
                 WHERE level = $level;"

    local result
    result=$(sqlite3 "$DB_FILE" "$query")

    if [ -z "$result" ]; then
        log_warning "No state found for level $level"
        return 1
    fi

    echo "$result"
    return 0
}

# Save test result
save_test_result() {
    local test_name=$1
    local status=$2
    local output=$3
    local duration=$4
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log_info "Saving test result for $test_name"

    local query="INSERT INTO test_results (test_name, status, output, duration, timestamp)
                 VALUES ('$test_name', $status, '$output', $duration, '$timestamp');"

    if ! sqlite3 "$DB_FILE" "$query"; then
        log_error "Failed to save test result"
        return 1
    fi

    log_success "Test result saved"
    return 0
}

# Get test results
get_test_results() {
    local test_name=${1:-"%"}

    local query="SELECT json_group_array(
                   json_object(
                     'test_name', test_name,
                     'status', status,
                     'output', output,
                     'duration', duration,
                     'timestamp', timestamp
                   )
                 )
                 FROM test_results
                 WHERE test_name LIKE '$test_name';"

    local results
    results=$(sqlite3 "$DB_FILE" "$query")

    if [ -z "$results" ]; then
        log_warning "No results found"
        return 1
    fi

    echo "$results"
    return 0
}

# Log test message
log_test_message() {
    local level=$1
    local message=$2
    local type=${3:-"info"}
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local query="INSERT INTO test_logs (level, message, type, timestamp)
                 VALUES ($level, '$message', '$type', '$timestamp');"

    if ! sqlite3 "$DB_FILE" "$query"; then
        log_error "Failed to log test message"
        return 1
    fi

    return 0
}

# Get test logs
get_test_logs() {
    local level=${1:-"%"}
    local type=${2:-"%"}

    local query="SELECT json_group_array(
                   json_object(
                     'level', level,
                     'message', message,
                     'type', type,
                     'timestamp', timestamp
                   )
                 )
                 FROM test_logs
                 WHERE level LIKE '$level'
                 AND type LIKE '$type'
                 ORDER BY timestamp DESC;"

    local logs
    logs=$(sqlite3 "$DB_FILE" "$query")

    if [ -z "$logs" ]; then
        log_warning "No logs found"
        return 1
    fi

    echo "$logs"
    return 0
}

# Clean old data
clean_old_data() {
    local days=${1:-7}
    log_info "Cleaning data older than $days days"

    local queries=(
        "DELETE FROM test_results WHERE timestamp < datetime('now', '-$days days');"
        "DELETE FROM test_logs WHERE timestamp < datetime('now', '-$days days');"
        "VACUUM;"
    )

    for query in "${queries[@]}"; do
        if ! sqlite3 "$DB_FILE" "$query"; then
            log_error "Failed to clean old data"
            return 1
        fi
    done

    log_success "Old data cleaned"
    return 0
}

# Export functions
export -f init_bridge
export -f verify_schema
export -f save_test_state
export -f get_test_state
export -f save_test_result
export -f get_test_results
export -f log_test_message
export -f get_test_logs
export -f clean_old_data 