#!/bin/bash

# Source Docker checks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/docker-check.sh"

# Common Docker settings
DOCKER_COMPOSE="docker compose"
DOCKER_SERVICE="test"
DOCKER_RUN="${DOCKER_COMPOSE} run -T --rm ${DOCKER_SERVICE}"

# Common packages needed in container
DEBIAN_PACKAGES="sqlite3 libsqlite3-dev gcc make git curl"

# Function to run a command in Docker with proper environment
docker_run() {
    # Ensure Docker is ready before running commands
    ensure_docker_ready

    echo "Running in Docker: $@"
    ${DOCKER_RUN} sh -c "
        apt-get update >/dev/null 2>&1 && \
        apt-get install -y ${DEBIAN_PACKAGES} >/dev/null 2>&1 && \
        $@"
}

# Export functions and variables
export -f docker_run
export DOCKER_RUN
export DEBIAN_PACKAGES 