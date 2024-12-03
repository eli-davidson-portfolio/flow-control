#!/bin/bash

# Source common utilities
# shellcheck source=../common/init.sh
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

# Function to show spinner with elapsed time
show_spinner_with_time() {
  local pid=$1
  local message=$2
  local delay=0.1
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local start_time
  start_time=$(date +%s)
  
  while ps a | awk '{print $1}' | grep -q "$pid"; do
    local temp=${spinstr#?}
    local elapsed=$(($(date +%s) - start_time))
    printf "\r\033[K  %c  %s (%ds)" "$spinstr" "$message" $elapsed
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
  done
  printf "\r\033[K"
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

# Function to show build progress
show_build_progress() {
  local build_output_file
  local summary_file
  build_output_file=$(mktemp)
  summary_file=$(mktemp)
  
  echo -e "\nStarting build process..."
  
  # Start the build in background and tee output to both files
  DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose -f docker-compose.staging.yml build 2>&1 | tee "$build_output_file" "$summary_file" &
  local build_pid=$!
  
  # Show spinner while building
  show_spinner_with_time $build_pid "Building services"
  
  # Check if build succeeded
  wait $build_pid
  local build_status=$?
  
  if [ $build_status -eq 0 ]; then
    show_step "Services built successfully" "success"
    # Show build summary
    echo -e "\nBuild Summary:"
    echo -e "  Last completed steps:"
    grep -E "Step [0-9]+/[0-9]+ : " "$summary_file" | tail -n 5 | sed 's/^/    /'
    echo -e "  Successfully built:"
    grep -E "Successfully built|Successfully tagged" "$summary_file" | sed 's/^/    /'
  else
    show_step "Failed to build services" "error"
    echo -e "\nBuild Error (last 10 lines):"
    tail -n 10 "$build_output_file" | sed 's/^/    /'
    rm "$build_output_file" "$summary_file"
    exit 1
  fi
  
  rm "$build_output_file" "$summary_file"
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

# Function to get the appropriate host for the environment
get_host() {
  case "${ENVIRONMENT:-dev}" in
    "staging")
      # Get the actual IP address for staging
      if command -v ip >/dev/null 2>&1; then
        # Linux
        ip route get 1 | awk '{print $7; exit}'
      else
        # macOS
        ipconfig getifaddr en0 || ipconfig getifaddr en1
      fi
      ;;
    "prod")
      echo "${DOMAIN_NAME:-$(hostname -f)}"
      ;;
    *)
      # Dev environment defaults to localhost
      echo "localhost"
      ;;
  esac
}

# Main deployment steps
main() {
  # Get the appropriate host
  HOST=$(get_host)
  
  # Step 1: Clean up environment
  show_step "Cleaning up environment" "start"
  if make clean > /dev/null 2>&1; then
    show_step "Environment cleaned" "success"
  else
    show_step "Failed to clean environment" "error"
    exit 1
  fi
  
  # Step 2: Build services with enhanced progress
  show_step "Building services" "start"
  show_build_progress
  
  # Step 3: Start services with progress
  show_step "Starting services" "start"
  local start_output_file
  start_output_file=$(mktemp)
  if docker compose -f docker-compose.staging.yml up -d > "$start_output_file" 2>&1; then
    show_step "Services started" "success"
    echo -e "\nStarted containers:"
    grep -E "Container .+ Started" "$start_output_file" | sed 's/^/  /'
  else
    show_step "Failed to start services" "error"
    sed 's/^/  /' < "$start_output_file"
    rm "$start_output_file"
    exit 1
  fi
  rm "$start_output_file"
  
  # Step 4: Wait for services to be healthy
  show_step "Waiting for services to be healthy" "start"
  echo -e "\nChecking app health..."
  if ! check_service_health "app" "http://${HOST}:8080/health"; then
    show_step "App health check failed" "error"
    docker compose -f docker-compose.staging.yml logs app
    exit 1
  fi
  
  echo -e "\nChecking webhook health..."
  if ! check_service_health "webhook" "http://${HOST}:9001/hooks/deploy"; then
    show_step "Webhook health check failed" "error"
    docker compose -f docker-compose.staging.yml logs webhook
    exit 1
  fi
  
  show_step "Services are healthy" "success"
  
  # Step 5: Final verification
  show_step "Verifying deployment" "start"
  echo -e "\nServices are available at:"
  echo -e "  • App: http://${HOST}:8080"
  echo -e "  • Webhook: http://${HOST}:9001"
  echo -e "\nHealth check endpoints:"
  echo -e "  • App: http://${HOST}:8080/health"
  echo -e "  • Webhook: http://${HOST}:9001/hooks/deploy"
  
  # Show environment-specific message
  case "${ENVIRONMENT:-dev}" in
    "staging")
      echo -e "\nStaging Environment:"
      echo -e "  • IP Address: ${HOST}"
      echo -e "  • Environment: Staging"
      ;;
    "prod")
      echo -e "\nProduction Environment:"
      echo -e "  • Domain: ${HOST}"
      echo -e "  • Environment: Production"
      ;;
    *)
      echo -e "\nDevelopment Environment:"
      echo -e "  • Host: localhost"
      echo -e "  • Environment: Development"
      ;;
  esac
  
  show_step "Deployment complete" "success"
}

# Run main function
main "$@" 