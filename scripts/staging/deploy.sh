#!/bin/bash

# Source common utilities
source "$(dirname "$0")/../common/init.sh"

# Clear screen and move cursor to top
clear
sleep 0.5

# ASCII art
cat << "EOF"
 _____ _                 ___           _           _ 
|  ___| | _____      __ / __\___  _ __ | |_ _ __ ___ | |
| |_  | |/ _ \ \ /\ / // /  / _ \| '_ \| __| '__/ _ \| |
|  _| | | (_) \ V  V // /__| (_) | | | | |_| | | (_) | |
|_|   |_|\___/ \_/\_/ \____/\___/|_| |_|\__|_|  \___/|_|
                                                        
EOF

# Add a newline after the logo
echo

# Function to show spinner
show_spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Function to show step progress
show_step() {
  local message=$1
  local status=$2
  local color=""
  local symbol=""
  
  case $status in
    "start")
      color="$BLUE"
      symbol="⟳"
      ;;
    "success")
      color="$GREEN"
      symbol="✓"
      ;;
    "error")
      color="$RED"
      symbol="✗"
      ;;
    *)
      color="$NC"
      symbol="•"
      ;;
  esac
  
  echo -e "${color}${symbol} ${message}${NC}"
}

# Function to check service health
check_service_health() {
  local service=$1
  local url=$2
  local max_retries=6
  local retry_count=0
  local delay=5
  
  while [ $retry_count -lt $max_retries ]; do
    echo -e "\nAttempt $((retry_count + 1))/$max_retries for $service:"
    local response
    response=$(curl -s -i "$url" || echo "Connection failed")
    echo "$response" | head -n 1
    
    if echo "$response" | grep -q "200 OK\|404 Not Found"; then
      # 404 is okay for webhook as it means the endpoint exists but needs POST
      return 0
    fi
    retry_count=$((retry_count + 1))
    [ $retry_count -lt $max_retries ] && sleep $delay
  done
  return 1
}

# Main deployment steps
main() {
  # Step 1: Clean up environment
  show_step "Cleaning up environment" "start"
  if make clean > /dev/null 2>&1; then
    show_step "Environment cleaned" "success"
  else
    show_step "Failed to clean environment" "error"
    exit 1
  fi
  
  # Step 2: Build services
  show_step "Building services" "start"
  if docker compose -f docker-compose.staging.yml build > /dev/null 2>&1; then
    show_step "Services built successfully" "success"
  else
    show_step "Failed to build services" "error"
    exit 1
  fi
  
  # Step 3: Start services
  show_step "Starting services" "start"
  if docker compose -f docker-compose.staging.yml up -d > /dev/null 2>&1; then
    show_step "Services started" "success"
  else
    show_step "Failed to start services" "error"
    exit 1
  fi
  
  # Step 4: Wait for services to be healthy
  show_step "Waiting for services to be healthy" "start"
  echo -e "\nChecking app health..."
  if ! check_service_health "app" "http://127.0.0.1:8080/health"; then
    show_step "App health check failed" "error"
    docker compose -f docker-compose.staging.yml logs app
    exit 1
  fi
  
  echo -e "\nChecking webhook health..."
  if ! check_service_health "webhook" "http://127.0.0.1:9001/hooks/deploy"; then
    show_step "Webhook health check failed" "error"
    docker compose -f docker-compose.staging.yml logs webhook
    exit 1
  fi
  
  show_step "Services are healthy" "success"
  
  # Step 5: Final verification
  show_step "Verifying deployment" "start"
  echo -e "\nServices are available at:"
  echo -e "  • App: http://127.0.0.1:8080"
  echo -e "  • Webhook: http://127.0.0.1:9001"
  echo -e "\nHealth check endpoints:"
  echo -e "  • App: http://127.0.0.1:8080/health"
  echo -e "  • Webhook: http://127.0.0.1:9001/hooks/deploy"
  show_step "Deployment complete" "success"
}

# Run main function
main "$@" 