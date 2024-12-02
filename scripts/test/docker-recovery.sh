#!/bin/bash
set -e

# Source Docker check script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/docker-check.sh"

# Colors for test output
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

log_scenario() {
    echo -e "\n${MAGENTA}[SCENARIO]${NC} $1"
    echo "----------------------------------------"
}

# Test Scenarios

test_missing_docker() {
    log_scenario "Testing missing Docker installation"
    
    # Simulate missing Docker
    local docker_path
    docker_path=$(which docker)
    sudo mv "$docker_path" "${docker_path}.bak"
    
    # Test recovery
    ensure_docker_ready
    local result=$?
    
    # Restore Docker
    sudo mv "${docker_path}.bak" "$docker_path"
    
    return $result
}

test_stopped_daemon() {
    log_scenario "Testing stopped Docker daemon"
    
    case "$(uname -s)" in
        Darwin)
            # Stop Docker Desktop
            osascript -e 'quit app "Docker Desktop"'
            ;;
        Linux)
            # Stop Docker daemon
            sudo systemctl stop docker
            ;;
    esac
    
    # Test recovery
    ensure_docker_ready
}

test_disk_space() {
    log_scenario "Testing disk space recovery"
    
    # Create large dummy containers and images
    log_test "Creating resource pressure..."
    for i in {1..5}; do
        docker run -d --name "dummy_$i" alpine dd if=/dev/zero of=/tmp/dummy bs=1M count=1000
    done
    
    # Test recovery
    ensure_docker_ready
    
    # Cleanup
    docker rm -f $(docker ps -aq) || true
}

test_permission_issues() {
    log_scenario "Testing permission issues"
    
    if [ "$(uname -s)" = "Linux" ]; then
        # Temporarily remove user from docker group
        local groups_backup
        groups_backup=$(groups)
        sudo gpasswd -d "$USER" docker
        
        # Test recovery
        ensure_docker_ready
        local result=$?
        
        # Restore groups
        for group in $groups_backup; do
            sudo usermod -aG "$group" "$USER"
        done
        
        return $result
    else
        log_test "Skipping permission test on non-Linux system"
        return 0
    fi
}

test_network_conflicts() {
    log_scenario "Testing network conflicts"
    
    # Create network with conflicting ports
    docker network create test_net
    docker run -d --name port_conflict --network test_net -p 8080:8080 nginx
    docker run -d --name port_conflict2 -p 8080:8080 nginx || true
    
    # Test recovery
    ensure_docker_ready
    
    # Cleanup
    docker rm -f port_conflict port_conflict2 || true
    docker network rm test_net || true
}

test_resource_exhaustion() {
    log_scenario "Testing resource exhaustion"
    
    # Create memory pressure
    log_test "Creating memory pressure..."
    docker run -d --name memory_hog --memory=512m alpine dd if=/dev/zero of=/dev/null
    
    # Create CPU pressure
    log_test "Creating CPU pressure..."
    docker run -d --name cpu_hog alpine dd if=/dev/zero of=/dev/null
    
    # Test recovery
    ensure_docker_ready
    
    # Cleanup
    docker rm -f memory_hog cpu_hog || true
}

test_corrupted_config() {
    log_scenario "Testing corrupted Docker configuration"
    
    case "$(uname -s)" in
        Darwin)
            # Backup and corrupt Docker Desktop settings
            cp ~/Library/Group\ Containers/group.com.docker/settings.json ~/Library/Group\ Containers/group.com.docker/settings.json.bak
            echo "{corrupted}" > ~/Library/Group\ Containers/group.com.docker/settings.json
            ;;
        Linux)
            # Backup and corrupt daemon.json
            sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
            echo "{corrupted}" | sudo tee /etc/docker/daemon.json
            ;;
    esac
    
    # Test recovery
    ensure_docker_ready
    local result=$?
    
    # Restore configuration
    case "$(uname -s)" in
        Darwin)
            mv ~/Library/Group\ Containers/group.com.docker/settings.json.bak ~/Library/Group\ Containers/group.com.docker/settings.json
            ;;
        Linux)
            sudo mv /etc/docker/daemon.json.bak /etc/docker/daemon.json
            ;;
    esac
    
    return $result
}

# Run all tests
run_all_tests() {
    log_test "Starting Docker recovery tests..."
    
    local failed_tests=()
    
    # Run each test and collect failures
    for test_func in test_missing_docker test_stopped_daemon test_disk_space \
                     test_permission_issues test_network_conflicts \
                     test_resource_exhaustion test_corrupted_config; do
        if ! $test_func; then
            failed_tests+=("$test_func")
        fi
    done
    
    # Report results
    echo
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_info "All recovery tests passed successfully!"
    else
        log_error "The following tests failed:"
        for test in "${failed_tests[@]}"; do
            echo "  - $test"
        done
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi 