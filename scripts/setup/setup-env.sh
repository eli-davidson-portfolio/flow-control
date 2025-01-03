#!/bin/bash
# setup-env.sh - Environment setup script for Flow Control
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/init.sh"

# Default values
ENV="staging"
USER="deploy"
INSTALL_DIR="/opt/flow-control"
BRANCH="staging"
WEBHOOK_PORT="9000"
APP_PORT="8080"
SKIP_MEMORY_CHECK="false"

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                ENV="$2"
                shift 2
                ;;
            --user)
                USER="$2"
                shift 2
                ;;
            --dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --branch)
                BRANCH="$2"
                shift 2
                ;;
            --webhook-port)
                WEBHOOK_PORT="$2"
                shift 2
                ;;
            --app-port)
                APP_PORT="$2"
                shift 2
                ;;
            --skip-memory-check)
                SKIP_MEMORY_CHECK="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Validate environment
    if [[ ! "$ENV" =~ ^(staging|production)$ ]]; then
        log_error "Invalid environment. Must be 'staging' or 'production'"
        exit 1
    fi
}

# Setup environment file
setup_env_file() {
    local base_dir="$1"
    local env="$2"
    
    log_info "Creating environment file..."
    
    cat > "$base_dir/.env.$env" << EOF
# Flow Control Environment Configuration
# Environment: $env
# Generated: $(date)

# Application Settings
ENVIRONMENT=$env
APP_PORT=$APP_PORT
WEBHOOK_PORT=$WEBHOOK_PORT
GO_ENV=$env

# Docker Settings
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1

# Database Settings
DB_PATH=/app/data/flow.db

# Logging
LOG_LEVEL=info
LOG_FORMAT=json
LOG_FILE=/app/logs/flow.log

# Runtime Settings
CGO_ENABLED=1
CONFIG_FILE=/app/config.json
EOF
    
    chmod 600 "$base_dir/.env.$env"
    
    # Verify file was created
    if [[ ! -f "$base_dir/.env.$env" ]]; then
        log_error "Failed to create environment file: $base_dir/.env.$env"
        return 1
    fi
    
    log_info "Environment file created successfully"
}

# Main setup function
main() {
    # Parse arguments
    parse_args "$@"
    
    # Create environment file
    setup_env_file "$INSTALL_DIR" "$ENV" || exit 1
    
    log_info "Setup completed successfully!"
}

# Run main function if script is executed directly
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@" 