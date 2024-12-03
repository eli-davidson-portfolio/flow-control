#!/bin/bash

# Source common utilities
source "$(dirname "$0")/../common/init.sh"

# Clear screen and move cursor to top
clear
sleep 0.5

# ASCII art
cat << "EOF"
 ____                _                                  _   
|  _ \  _____   __ | |    ___   __ _ _ __ ___   ___ | |_ 
| | | |/ _ \ \ / / | |   / _ \ / _' | '_ ' _ \ / _ \| __|
| |_| |  __/\ V /  | |__| (_) | (_| | | | | | | (_) | |_ 
|____/ \___| \_/   |_____\___/ \__, |_| |_| |_|\___/ \__|
                               |___/                       
EOF

# Add a newline after the logo
echo

# Function to show spinner with elapsed time
show_spinner_with_time() {
  local pid=$1
  local message=$2
  local delay=0.1
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local start_time=$(date +%s)
  
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
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

# Function to show container status
show_container_status() {
  local container_name=$1
  local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
  local health=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null)
  
  if [ -n "$status" ]; then
    if [ "$status" = "running" ]; then
      if [ "$health" = "healthy" ]; then
        echo -e "  • ${GREEN}$container_name: $status (healthy)${NC}"
      else
        echo -e "  • ${YELLOW}$container_name: $status${NC}"
      fi
    else
      echo -e "  • ${RED}$container_name: $status${NC}"
    fi
  else
    echo -e "  • ${RED}$container_name: not found${NC}"
  fi
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
      return 0
    fi
    retry_count=$((retry_count + 1))
    [ $retry_count -lt $max_retries ] && sleep $delay
  done
  return 1
}

# Function to show build progress
show_build_progress() {
  local build_output_file=$(mktemp)
  local summary_file=$(mktemp)
  
  echo -e "\nStarting build process..."
  
  # Start the build in background and tee output to both files
  docker compose build 2>&1 | tee "$build_output_file" "$summary_file" &
  local build_pid=$!
  
  # Show spinner while building
  show_spinner_with_time $build_pid "Building services"
  
  # Check if build succeeded
  wait $build_pid
  local build_status=$?
  
  if [ $build_status -eq 0 ]; then
    show_step "Services built successfully" "success"
  else
    show_step "Failed to build services" "error"
    echo -e "\nBuild Error (last 10 lines):"
    tail -n 10 "$build_output_file" | sed 's/^/    /'
    rm "$build_output_file" "$summary_file"
    exit 1
  fi
  
  rm "$build_output_file" "$summary_file"
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
  show_build_progress
  
  # Step 3: Start development environment
  show_step "Starting development environment" "start"
  local start_output_file=$(mktemp)
  if docker compose up -d dev test > "$start_output_file" 2>&1; then
    show_step "Development environment started" "success"
    
    # Show container status
    echo -e "\nContainer Status:"
    show_container_status "flow-control-dev-1"
    show_container_status "flow-control-test-1"
    
    # Step 4: Wait for services to be healthy
    show_step "Waiting for services to be healthy" "start"
    echo -e "\nChecking app health..."
    if ! check_service_health "app" "http://localhost:8080/health"; then
      show_step "App health check failed" "error"
      docker compose logs dev
      exit 1
    fi
    show_step "Services are healthy" "success"
    
    # Show environment info
    echo -e "\nDevelopment Environment:"
    echo -e "  • Environment: Development"
    echo -e "  • Host: localhost"
    echo -e "  • Hot Reload: Enabled"
    echo -e "  • Test Container: Ready"
    
    # Show access URLs
    echo -e "\nAccess URLs:"
    echo -e "  • App: http://localhost:8080"
    echo -e "  • API Docs: http://localhost:8080/swagger/index.html"
    echo -e "  • Health: http://localhost:8080/health"
    
    # Show helpful commands
    echo -e "\nUseful Commands:"
    echo -e "  • View logs: make logs"
    echo -e "  • Run tests: make test"
    echo -e "  • Stop environment: make clean"
  else
    show_step "Failed to start development environment" "error"
    echo -e "\nStart Error:"
    cat "$start_output_file" | sed 's/^/  /'
    rm "$start_output_file"
    exit 1
  fi
  rm "$start_output_file"
  
  show_step "Development environment ready" "success"
}

# Run main function
main "$@" 