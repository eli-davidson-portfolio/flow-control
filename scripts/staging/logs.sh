#!/bin/bash

# Source common utilities
source "$(dirname "$0")/../common/init.sh"

# Clear screen and move cursor to top
clear
sleep 0.5

# ASCII art
cat << "EOF"
 _                    
| |    ___   __ _ ___ 
| |   / _ \ / _' / __|
| |__| (_) | (_| \__ \
|_____\___/ \__, |___/
            |___/     
EOF

# Add a newline after the logo
echo

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

# Function to capture logs
capture_logs() {
  local log_dir="logs/deploy-$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$log_dir"
  
  # Capture container logs
  show_step "Capturing container logs" "start"
  docker compose -f docker-compose.staging.yml logs --no-color > "$log_dir/containers.log" 2>&1
  show_step "Container logs saved to $log_dir/containers.log" "success"
  
  # Capture container status
  show_step "Capturing container status" "start"
  {
    echo "Container Status:"
    echo "----------------"
    docker compose -f docker-compose.staging.yml ps
    echo
    echo "Container Details:"
    echo "-----------------"
    docker inspect flow-control-app-1 flow-control-webhook-1
  } > "$log_dir/status.log" 2>&1
  show_step "Container status saved to $log_dir/status.log" "success"
  
  # Capture system info
  show_step "Capturing system info" "start"
  {
    echo "System Info:"
    echo "------------"
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo "Docker Version: $(docker version --format '{{.Server.Version}}')"
    echo "Docker Compose Version: $(docker compose version)"
    echo
    echo "Docker Info:"
    echo "-----------"
    docker info
  } > "$log_dir/system.log" 2>&1
  show_step "System info saved to $log_dir/system.log" "success"
  
  # Show summary
  echo -e "\nLogs have been captured to: $log_dir"
  echo -e "Files:"
  echo -e "  • containers.log - Container logs"
  echo -e "  • status.log    - Container status and details"
  echo -e "  • system.log    - System information"
}

# Main function
main() {
  capture_logs
}

# Run main function
main "$@" 