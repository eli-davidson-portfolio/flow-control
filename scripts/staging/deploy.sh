#!/bin/bash
# deploy.sh - Staging deployment script
set -e

# Source common functions
source "$(dirname "$0")/../common/init.sh"

# Configuration
DEPLOY_LOG="logs/deploy.log"
BACKUP_DIR="data/backups"
MAX_BACKUPS=7

# Initialize logging
mkdir -p "$(dirname "$DEPLOY_LOG")"
exec 1> >(tee -a "$DEPLOY_LOG") 2>&1

log_info "Starting deployment at $(date)"

# Function to backup database
backup_database() {
    log_info "Backing up database..."
    mkdir -p "$BACKUP_DIR"
    
    # Create backup with timestamp
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/pre_deploy_${timestamp}.sql"
    
    if [ -f "data/flow.db" ]; then
        sqlite3 data/flow.db ".backup '$backup_file'"
        log_info "Database backed up to $backup_file"
        
        # Clean old backups
        local backup_count
        backup_count=$(ls -1 "$BACKUP_DIR"/pre_deploy_*.sql 2>/dev/null | wc -l)
        if [ "$backup_count" -gt "$MAX_BACKUPS" ]; then
            ls -1t "$BACKUP_DIR"/pre_deploy_*.sql | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
            log_info "Cleaned old backups, keeping last $MAX_BACKUPS"
        fi
    else
        log_warn "No database found to backup"
    fi
}

# Function to update code
update_code() {
    log_info "Updating code..."
    
    # Fetch latest changes
    git fetch origin
    
    # Store current commit for rollback
    echo "$(git rev-parse HEAD)" > .last_deploy
    
    # Update to latest
    git pull origin staging
    
    log_info "Code updated to $(git rev-parse HEAD)"
}

# Function to verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Wait for application to start
    sleep 5
    
    # Run health check
    if ! curl -s http://localhost:8080/health | grep -q "ok"; then
        log_error "Health check failed"
        return 1
    fi
    
    log_info "Deployment verified successfully"
}

# Main deployment process
main() {
    # Ensure we're in the project root
    cd "$(git rev-parse --show-toplevel)"
    
    # Run deployment steps
    backup_database
    update_code
    
    # Stop current deployment and start new one
    log_info "Restarting application..."
    make staging
    
    verify_deployment
    
    log_info "Deployment completed successfully at $(date)"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if ! main "$@"; then
        log_error "Deployment failed"
        if [ -f .last_deploy ]; then
            log_info "Rolling back to $(cat .last_deploy)"
            git reset --hard "$(cat .last_deploy)"
            make staging
        fi
        exit 1
    fi
fi 