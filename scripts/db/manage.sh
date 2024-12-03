#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common utilities
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"

# Configuration
DB_DIR="$PROJECT_ROOT/data/db"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"
BACKUP_DIR="$PROJECT_ROOT/backups/db"
MAIN_DB="$DB_DIR/audit.db"
BACKUP_RETENTION_DAYS=30

# Initialize directories
init_dirs() {
    mkdir -p "$DB_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$MIGRATIONS_DIR"
}

# Create backup filename with timestamp
get_backup_filename() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    echo "${BACKUP_DIR}/audit_${timestamp}.db"
}

# Backup database
backup_db() {
    log_header "Backing up database"
    
    if [ ! -f "$MAIN_DB" ]; then
        log_warning "No database found to backup"
        return 0
    fi
    
    local backup_file=$(get_backup_filename)
    
    # Create backup
    if sqlite3 "$MAIN_DB" ".backup '$backup_file'"; then
        log_success "Database backed up to: $backup_file"
        
        # Compress backup
        gzip "$backup_file"
        log_success "Backup compressed: ${backup_file}.gz"
        
        # Clean old backups
        find "$BACKUP_DIR" -name "audit_*.db.gz" -mtime +$BACKUP_RETENTION_DAYS -delete
        log_info "Cleaned up old backups"
    else
        log_error "Backup failed"
        return 1
    fi
}

# Get current schema version
get_current_version() {
    if [ ! -f "$MAIN_DB" ]; then
        echo "0"
        return
    fi
    
    sqlite3 "$MAIN_DB" "SELECT COALESCE(MAX(version), 0) FROM schema_migrations;" 2>/dev/null || echo "0"
}

# Get available migrations
get_available_migrations() {
    find "$MIGRATIONS_DIR" -name "*.sql" | sort
}

# Apply single migration
apply_migration() {
    local file="$1"
    local version=$(basename "$file" | cut -d'_' -f1)
    local name=$(basename "$file" | cut -d'_' -f2- | sed 's/\.sql$//')
    
    log_step "Applying migration $version: $name"
    
    # Start transaction
    sqlite3 "$MAIN_DB" "BEGIN TRANSACTION;"
    
    # Apply migration
    if sqlite3 "$MAIN_DB" < "$file"; then
        # Record migration
        sqlite3 "$MAIN_DB" "INSERT INTO schema_migrations (version, name) VALUES ($version, '$name');"
        sqlite3 "$MAIN_DB" "COMMIT;"
        log_success "Migration $version applied successfully"
        return 0
    else
        sqlite3 "$MAIN_DB" "ROLLBACK;"
        log_error "Migration $version failed"
        return 1
    fi
}

# Run migrations
run_migrations() {
    log_header "Running database migrations"
    
    local current_version=$(get_current_version)
    log_info "Current database version: $current_version"
    
    # Create schema_migrations table if it doesn't exist
    sqlite3 "$MAIN_DB" "CREATE TABLE IF NOT EXISTS schema_migrations (
        id INTEGER PRIMARY KEY,
        version INTEGER NOT NULL,
        name TEXT NOT NULL,
        applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );"
    
    # Apply each migration in order
    while read -r migration_file; do
        local version=$(basename "$migration_file" | cut -d'_' -f1)
        if [ "$version" -gt "$current_version" ]; then
            if ! apply_migration "$migration_file"; then
                return 1
            fi
        fi
    done < <(get_available_migrations)
    
    log_success "All migrations applied successfully"
}

# Verify database integrity
verify_db() {
    log_header "Verifying database integrity"
    
    if [ ! -f "$MAIN_DB" ]; then
        log_error "Database file not found"
        return 1
    fi
    
    if sqlite3 "$MAIN_DB" "PRAGMA integrity_check;" | grep -q "ok"; then
        log_success "Database integrity verified"
        return 0
    else
        log_error "Database integrity check failed"
        return 1
    fi
}

# Show database status
show_status() {
    log_header "Database Status"
    
    if [ ! -f "$MAIN_DB" ]; then
        log_warning "Database does not exist"
        return 0
    fi
    
    local version=$(get_current_version)
    local size=$(du -h "$MAIN_DB" | cut -f1)
    local tables=$(sqlite3 "$MAIN_DB" "SELECT name FROM sqlite_master WHERE type='table';" | wc -l)
    
    echo "Version: $version"
    echo "Size: $size"
    echo "Tables: $tables"
    echo
    echo "Recent migrations:"
    sqlite3 "$MAIN_DB" "SELECT version, name, datetime(applied_at) FROM schema_migrations ORDER BY version DESC LIMIT 5;"
}

# Main execution
main() {
    local command="${1:-help}"
    
    init_dirs
    
    case "$command" in
        migrate)
            backup_db && run_migrations
            ;;
        backup)
            backup_db
            ;;
        verify)
            verify_db
            ;;
        status)
            show_status
            ;;
        help)
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  migrate    Run pending migrations"
            echo "  backup     Create database backup"
            echo "  verify     Check database integrity"
            echo "  status     Show database status"
            echo "  help       Show this help message"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 