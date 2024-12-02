#!/bin/bash
# setup-env.sh - Environment setup script for Flow Control
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/init.sh"

# Function to follow Docker logs
follow_docker_logs() {
    echo "Following Docker logs in real-time (Ctrl+C to stop viewing logs)..."
    docker compose -f docker-compose.yml -f docker-compose.staging.yml logs -f &
    LOGS_PID=$!
    trap 'kill $LOGS_PID 2>/dev/null' EXIT
}

# Default values
ENV="staging"
USER="deploy"
INSTALL_DIR="/opt/flow-control"
REPO="git@github.com:elleshadow/flow-control.git"
BRANCH="staging"
DOMAIN=""
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
            --repo)
                REPO="$2"
                shift 2
                ;;
            --branch)
                BRANCH="$2"
                shift 2
                ;;
            --domain)
                DOMAIN="$2"
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

# Check system requirements
check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check memory
    local mem_total
    mem_total=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $mem_total -lt 2048 ]]; then
        if [[ "$SKIP_MEMORY_CHECK" == "true" ]]; then
            log_warn "Low memory detected. Required: 2GB, Available: ${mem_total}MB. Continuing anyway as --skip-memory-check was specified."
        else
            log_error "Insufficient memory. Required: 2GB, Available: ${mem_total}MB"
            log_error "Use --skip-memory-check to override this check if you're sure about running with less memory."
            exit 1
        fi
    fi
    
    # Check disk space
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ $disk_usage -gt 80 ]]; then
        log_error "Insufficient disk space. Available: $((100-disk_usage))%"
        exit 1
    fi
}

# Install Docker and dependencies
install_docker() {
    log_info "Installing Docker and dependencies..."
    
    # Install prerequisites
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Start and enable Docker
    systemctl enable docker
    systemctl start docker

    log_info "Docker installed successfully"
}

# Install required packages
install_packages() {
    log_info "Installing required packages..."
    
    # First, install Docker if not present
    if ! command -v docker &> /dev/null; then
        install_docker
    else
        log_info "Docker already installed"
    fi
    
    # Install other required packages
    local packages=(
        git
        jq
        curl
        sqlite3
        nginx
        webhook
        ufw
    )
    
    # Install packages based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - use Homebrew
        if ! command -v brew &> /dev/null; then
            log_error "Homebrew is required but not installed. Please install Homebrew first: https://brew.sh"
            exit 1
        fi
        
        for pkg in "${packages[@]}"; do
            brew install "$pkg" || true
        done
    else
        # Assume Debian/Ubuntu
        apt-get update
        apt-get install -y "${packages[@]}"
    fi
}

# Setup deploy user
setup_user() {
    local username="$1"
    
    if ! id -u "$username" &>/dev/null; then
        log_info "Creating user $username..."
        useradd -m -s /bin/bash "$username"
        usermod -aG sudo "$username"
        usermod -aG docker "$username"
    else
        log_info "User $username already exists"
    fi
}

# Setup directories
setup_directories() {
    local base_dir="$1"
    
    log_info "Creating directories..."
    mkdir -p "$base_dir"/{scripts,config,logs,data/backups}
    
    # Set permissions
    chown -R "$USER:$USER" "$base_dir"
}

# Setup SSH
setup_ssh() {
    local base_dir="$1"
    local env="$2"
    
    log_info "Setting up SSH..."
    
    # Create SSH directory
    local ssh_dir="$base_dir/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Generate deploy key
    if [[ ! -f "$ssh_dir/id_ed25519" ]]; then
        ssh-keygen -t ed25519 -f "$ssh_dir/id_ed25519" -N "" -C "deploy@${env}"
    fi
    
    # Configure SSH
    cat > "$ssh_dir/config" << EOF
Host github.com
    IdentityFile $ssh_dir/id_ed25519
    StrictHostKeyChecking no
EOF
    
    chmod 600 "$ssh_dir/config"
    chown -R "$USER:$USER" "$ssh_dir"
    
    # Display public key
    log_info "Add this deploy key to GitHub:"
    cat "$ssh_dir/id_ed25519.pub"
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
    chown "$USER:$USER" "$base_dir/.env.$env"
    
    # Verify file was created
    if [[ ! -f "$base_dir/.env.$env" ]]; then
        log_error "Failed to create environment file: $base_dir/.env.$env"
        return 1
    fi
    
    log_info "Environment file created successfully"
}

# Setup Nginx
setup_nginx() {
    local domain="$1"
    local port="$2"
    
    if [[ -z "$domain" ]]; then
        log_info "Skipping Nginx setup (no domain provided)"
        return 0
    fi
    
    log_info "Configuring Nginx..."
    
    # Create Nginx config
    cat > "/etc/nginx/sites-available/$domain" << EOF
server {
    listen 80;
    server_name $domain;
    
    location / {
        proxy_pass http://localhost:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    # Enable site
    ln -sf "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/"
    
    # Test and reload
    nginx -t
    systemctl reload nginx
}

# Setup webhook
setup_webhook() {
    local base_dir="$1"
    local port="$2"
    
    log_info "Setting up webhook..."
    
    # Create webhook config
    mkdir -p "$base_dir/config"
    cat > "$base_dir/config/hooks.json" << EOF
[
  {
    "id": "deploy",
    "execute-command": "$base_dir/scripts/staging/deploy.sh",
    "command-working-directory": "$base_dir",
    "response-message": "Deploying...",
    "trigger-rule": {
      "match": {
        "type": "value",
        "value": "refs/heads/$BRANCH",
        "parameter": {
          "source": "payload",
          "name": "ref"
        }
      }
    }
  }
]
EOF
    
    # Create systemd service
    cat > "/etc/systemd/system/webhook.service" << EOF
[Unit]
Description=GitHub webhook server
After=network.target

[Service]
User=$USER
ExecStart=/usr/bin/webhook -hooks $base_dir/config/hooks.json -port $port -verbose
WorkingDirectory=$base_dir
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    # Start service
    systemctl daemon-reload
    systemctl enable webhook
    systemctl start webhook
}

# Setup Docker
setup_docker() {
    log_info "Setting up Docker..."
    
    # Start Docker
    systemctl enable docker
    systemctl start docker
    
    # Create Docker network
    docker network create flow-network || true
}

# Setup firewall
setup_firewall() {
    local http_port="$1"
    local webhook_port="$2"
    local app_port="$3"
    
    log_info "Configuring firewall..."
    
    # Enable UFW
    ufw --force enable
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP/HTTPS
    [[ -n "$http_port" ]] && ufw allow "$http_port/tcp"
    
    # Allow webhook
    ufw allow "$webhook_port/tcp"
    
    # Allow application
    ufw allow "$app_port/tcp"
    
    # Reload
    ufw reload
}

# Setup Git repository
setup_git() {
    local base_dir="$1"
    local repo="$2"
    local branch="$3"
    
    log_info "Setting up Git repository..."
    
    # Configure Git
    git config --global init.defaultBranch main
    git config --global --add safe.directory "$base_dir"
    
    # Save current directory
    local current_dir
    current_dir=$(pwd)
    
    # Remove existing directory if it exists
    if [[ -d "$base_dir" ]]; then
        log_info "Removing existing directory..."
        rm -rf "$base_dir"
    fi
    
    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$base_dir")"
    
    # Clone repository directly into target directory
    log_info "Cloning repository..."
    git clone -b "$branch" "$repo" "$base_dir" || {
        cd "$current_dir"
        log_error "Failed to clone repository. Please check your SSH access and try again."
        return 1
    }
    
    # Set permissions
    chown -R "$USER:$USER" "$base_dir"
    
    # Return to original directory
    cd "$current_dir"
    
    log_info "Repository setup complete"
}

# Get server IP address
get_server_ip() {
    # Try to get the primary IP address
    local ip
    if command -v ip &> /dev/null; then
        ip=$(ip route get 1 | awk '{print $7; exit}')
    elif command -v hostname &> /dev/null; then
        ip=$(hostname -I | awk '{print $1}')
    else
        ip="localhost"
    fi
    echo "$ip"
}

verify_application() {
    local base_dir="$1"
    local max_attempts=12  # 60 seconds total (5 seconds * 12)
    local attempt=1
    local server_ip
    
    server_ip=$(get_server_ip)
    
    log_info "Verifying application startup..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://${server_ip}:8080/health" | grep -q "ok"; then
            log_info "Application is running successfully at http://${server_ip}:8080"
            return 0
        fi
        
        log_info "Waiting for application to start (attempt $attempt/$max_attempts)..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log_error "Application failed to start properly after $(( max_attempts * 5 )) seconds"
    log_info "Checking application logs..."
    
    if [ -f "${base_dir}/logs/app.log" ]; then
        tail -n 50 "${base_dir}/logs/app.log"
    else
        docker compose -f "${base_dir}/docker-compose.yml" -f "${base_dir}/docker-compose.staging.yml" logs
    fi
    
    return 1
}

start_application() {
    local base_dir="$1"
    
    log_info "Starting application..."
    
    if [[ ! -f "${base_dir}/.env.staging" ]]; then
        log_error "Environment file not found"
        return 1
    fi
    
    cd "${base_dir}"
    
    if ! make staging; then
        log_error "Failed to start application"
        return 1
    fi
    
    # Verify the application is running
    if ! verify_application "${base_dir}"; then
        return 1
    fi
    
    return 0
}

# Main setup function
main() {
    # Parse arguments
    parse_args "$@"
    
    # Run setup steps
    check_system_requirements || exit 1
    install_packages || exit 1
    setup_user "$USER" || exit 1
    setup_directories "$INSTALL_DIR" || exit 1
    setup_ssh "$INSTALL_DIR" "$ENV" || exit 1
    [[ -n "$DOMAIN" ]] && setup_nginx "$DOMAIN" "$APP_PORT"
    setup_webhook "$INSTALL_DIR" "$WEBHOOK_PORT" || exit 1
    setup_docker || exit 1
    setup_firewall "80" "$WEBHOOK_PORT" "$APP_PORT" || exit 1
    
    # Get server IP
    local server_ip
    server_ip=$(get_server_ip)
    
    # Display deploy key and wait for user
    log_info "IMPORTANT: Add the following deploy key to GitHub before continuing:"
    cat "$INSTALL_DIR/.ssh/id_ed25519.pub"
    log_info "1. Go to GitHub repository → Settings → Deploy Keys"
    log_info "2. Click 'Add deploy key'"
    log_info "3. Title: 'Staging Server'"
    log_info "4. Paste the key above"
    log_info "5. Check 'Allow write access' if needed"
    
    read -p "Press Enter after adding the deploy key to GitHub..."
    
    # Continue with Git setup
    setup_git "$INSTALL_DIR" "$REPO" "$BRANCH" || exit 1
    
    # Create environment file after Git setup
    setup_env_file "$INSTALL_DIR" "$ENV" || exit 1
    
    log_info "Setup completed successfully!"
    
    # Verify environment file exists before asking to start
    if [[ ! -f "$INSTALL_DIR/.env.$ENV" ]]; then
        log_error "Environment file not found after setup. Cannot start application."
        exit 1
    fi
    
    # Ask before starting application
    read -p "Would you like to start the application now? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        if ! start_application "$INSTALL_DIR"; then
            log_error "Application startup failed. Please check the logs and try again."
            exit 1
        fi
    else
        log_info "You can start the application later with: cd $INSTALL_DIR && make staging"
    fi
    
    log_info "Next steps:"
    log_info "1. The deploy key has been added to GitHub"
    log_info "2. Environment variables are configured in $INSTALL_DIR/.env.$ENV"
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        log_info "3. The application should now be running at http://${server_ip}:8080"
    fi
}

# Run main function if script is executed directly
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@" 