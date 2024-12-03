#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source dependencies
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"

# Configuration
BACKUP_DIR="$PROJECT_ROOT/backups/cleanup_$(date +%Y%m%d_%H%M%S)"

# Create backup of current state
backup_current_state() {
    log_header "Backing up current state"
    mkdir -p "$BACKUP_DIR"
    
    # Create tar archive of current state
    tar -czf "$BACKUP_DIR/project_backup.tar.gz" \
        --exclude=".git" \
        --exclude="vendor" \
        --exclude="bin" \
        --exclude="tmp" \
        --exclude="backups" \
        -C "$PROJECT_ROOT" .
    
    log_success "Backup created at: $BACKUP_DIR"
}

# Clean up test directories
cleanup_tests() {
    log_header "Cleaning up test directories"
    
    # Create new test structure
    mkdir -p "$PROJECT_ROOT/tests/"{integration,unit,framework}
    
    # Move existing tests
    if [ -d "$PROJECT_ROOT/test" ]; then
        mv "$PROJECT_ROOT/test"/* "$PROJECT_ROOT/tests/unit/" 2>/dev/null || true
        rm -rf "$PROJECT_ROOT/test"
    fi
    
    if [ -d "$PROJECT_ROOT/tests" ]; then
        mv "$PROJECT_ROOT/tests"/* "$PROJECT_ROOT/tests/framework/" 2>/dev/null || true
        rm -rf "$PROJECT_ROOT/tests"
    fi
    
    log_success "Test directories reorganized"
}

# Clean up script directories
cleanup_scripts() {
    log_header "Cleaning up script directories"
    
    # Create new script structure
    mkdir -p "$PROJECT_ROOT/scripts/"{dev,ops,verify,lib}
    
    # Move verification scripts
    if [ -d "$PROJECT_ROOT/scripts/verify" ]; then
        mv "$PROJECT_ROOT/scripts/verify"/* "$PROJECT_ROOT/scripts/verify/" 2>/dev/null || true
    fi
    
    # Move development scripts
    if [ -d "$PROJECT_ROOT/scripts/dev" ]; then
        mv "$PROJECT_ROOT/scripts/dev"/* "$PROJECT_ROOT/scripts/dev/" 2>/dev/null || true
    fi
    
    # Move operation scripts
    for dir in deploy staging environments tasks; do
        if [ -d "$PROJECT_ROOT/scripts/$dir" ]; then
            mv "$PROJECT_ROOT/scripts/$dir"/* "$PROJECT_ROOT/scripts/ops/" 2>/dev/null || true
            rm -rf "$PROJECT_ROOT/scripts/$dir"
        fi
    done
    
    log_success "Script directories reorganized"
}

# Clean up configuration
cleanup_config() {
    log_header "Cleaning up configuration"
    
    # Create new config structure
    mkdir -p "$PROJECT_ROOT/config/"{dev,staging,production}
    
    # Move environment files
    if [ -f "$PROJECT_ROOT/.env.dev" ]; then
        mv "$PROJECT_ROOT/.env.dev" "$PROJECT_ROOT/config/dev/"
    fi
    if [ -f "$PROJECT_ROOT/.env.staging" ]; then
        mv "$PROJECT_ROOT/.env.staging" "$PROJECT_ROOT/config/staging/"
    fi
    if [ -f "$PROJECT_ROOT/.env.production" ]; then
        mv "$PROJECT_ROOT/.env.production" "$PROJECT_ROOT/config/production/"
    fi
    
    # Move Docker files
    if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        mv "$PROJECT_ROOT/docker-compose.yml" "$PROJECT_ROOT/config/dev/"
    fi
    if [ -f "$PROJECT_ROOT/docker-compose.staging.yml" ]; then
        mv "$PROJECT_ROOT/docker-compose.staging.yml" "$PROJECT_ROOT/config/staging/"
    fi
    
    log_success "Configuration files reorganized"
}

# Clean up build system
cleanup_build() {
    log_header "Cleaning up build system"
    
    # Create new build structure
    mkdir -p "$PROJECT_ROOT/build/"{dev,staging,production}
    
    # Move build scripts
    if [ -d "$PROJECT_ROOT/scripts/build" ]; then
        mv "$PROJECT_ROOT/scripts/build"/* "$PROJECT_ROOT/build/" 2>/dev/null || true
        rm -rf "$PROJECT_ROOT/scripts/build"
    fi
    
    log_success "Build system reorganized"
}

# Update import paths
update_imports() {
    log_header "Updating import paths"
    
    # Update Go imports
    if command -v goimports >/dev/null 2>&1; then
        find "$PROJECT_ROOT" -type f -name "*.go" -exec goimports -w {} \;
    else
        log_warning "goimports not found, skipping import updates"
    fi
    
    log_success "Import paths updated"
}

# Clean up temporary files
cleanup_temp() {
    log_header "Cleaning up temporary files"
    
    # Remove temporary directories
    rm -rf "$PROJECT_ROOT/tmp"
    rm -rf "$PROJECT_ROOT/coverage"
    
    # Remove test files
    rm -f "$PROJECT_ROOT/test.txt"
    rm -f "$PROJECT_ROOT/test_file_perms.txt"
    
    log_success "Temporary files cleaned up"
}

# Main cleanup function
main() {
    log_header "Starting project cleanup"
    
    # Create backup first
    backup_current_state
    
    # Run cleanup tasks
    cleanup_tests
    cleanup_scripts
    cleanup_config
    cleanup_build
    update_imports
    cleanup_temp
    
    log_header "Cleanup Summary"
    log_success "Project structure has been reorganized"
    log_info "Backup created at: $BACKUP_DIR"
    log_info "Please review changes and run tests to ensure everything works"
}

# Run main function
main 