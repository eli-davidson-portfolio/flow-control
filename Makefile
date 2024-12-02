# Use bash for shell commands
SHELL := /bin/bash

# Source progress script
PROGRESS_SCRIPT := scripts/common/progress.sh
PROGRESS_FUNCTIONS := $(shell bash -c ". $(PROGRESS_SCRIPT) && declare -F | cut -d' ' -f3")

# Environment settings
INSTALL_DIR := $(shell pwd)

.PHONY: all build run test clean lint fmt check install-tools pre-commit dev docker-test docker-check setup-staging verify-staging clean-env clean-env-force

all: check build

# Helper target for force cleanup
clean-env-force:
	@echo "Performing force cleanup..."
	@# Stop all running containers
	@docker stop $$(docker ps -aq) >/dev/null 2>&1 || true
	@# Remove all containers
	@docker rm -f $$(docker ps -aq) >/dev/null 2>&1 || true
	@# Remove all images
	@docker rmi -f $$(docker images -aq) >/dev/null 2>&1 || true
	@# Remove all volumes
	@docker volume rm $$(docker volume ls -q) >/dev/null 2>&1 || true
	@# Remove all networks
	@docker network prune -f >/dev/null 2>&1 || true
	@# Remove all build cache
	@docker builder prune -af >/dev/null 2>&1 || true
	@# Kill ALL Docker processes
	@pkill -9 docker >/dev/null 2>&1 || true
	@systemctl restart docker >/dev/null 2>&1 || true
	@sleep 10  # Give Docker time to restart
	@echo "Force cleanup complete"

# Helper target to ensure clean environment
clean-env:
	@bash -c ". $(PROGRESS_SCRIPT) && \
		echo 'Cleaning up environment...' && \
		# Stop and remove all containers first \
		docker compose down -v >/dev/null 2>&1 || true && \
		docker compose -f docker-compose.yml -f docker-compose.staging.yml down -v >/dev/null 2>&1 || true && \
		docker rm -f flow-control-app-1 flow-control-webhook-1 2>/dev/null || true && \
		# Remove and recreate network \
		docker network rm flow-network 2>/dev/null || true && \
		docker network create flow-network 2>/dev/null || true && \
		# Kill any processes using our ports (try multiple methods) \
		status_msg 'Releasing ports...' 'info' && \
		# Method 1: Using ss \
		(ss -lptn 'sport = :8080' | grep -oP '(?<=pid=).*?(?=,|$)' | xargs kill -9) >/dev/null 2>&1 || true && \
		(ss -lptn 'sport = :9000' | grep -oP '(?<=pid=).*?(?=,|$)' | xargs kill -9) >/dev/null 2>&1 || true && \
		# Method 2: Using netstat \
		(netstat -tlpn 2>/dev/null | grep ':8080' | awk '{print $$7}' | cut -d'/' -f1 | xargs kill -9) >/dev/null 2>&1 || true && \
		(netstat -tlpn 2>/dev/null | grep ':9000' | awk '{print $$7}' | cut -d'/' -f1 | xargs kill -9) >/dev/null 2>&1 || true && \
		# Method 3: Using lsof \
		(lsof -ti:8080 | xargs kill -9) >/dev/null 2>&1 || true && \
		(lsof -ti:9000 | xargs kill -9) >/dev/null 2>&1 || true && \
		# Method 4: Using fuser \
		(fuser -k 8080/tcp) >/dev/null 2>&1 || true && \
		(fuser -k 9000/tcp) >/dev/null 2>&1 || true && \
		# Give the system time to fully release the ports \
		sleep 5 && \
		# Verify ports are free \
		if netstat -ln | grep -q ':8080 \|:9000 '; then \
			status_msg 'Standard cleanup failed to free ports, attempting force cleanup...' 'warning' && \
			$(MAKE) clean-env-force && \
			if netstat -ln | grep -q ':8080 \|:9000 '; then \
				status_msg 'Failed to free ports even after force cleanup' 'error' && \
				exit 1; \
			fi; \
		fi"

# Verify staging deployment
verify-staging:
	@bash -c ". $(PROGRESS_SCRIPT) && \
		status_msg 'Verifying deployment...' 'info' && \
		echo 'Waiting for services to initialize...' && \
		sleep 5 && \
		HOST_IP=$$(hostname -I | awk '{print $$1}') && \
		MAX_RETRIES=12 && \
		RETRY_COUNT=0 && \
		while [ \$$RETRY_COUNT -lt \$$MAX_RETRIES ]; do \
			if curl -s http://localhost:8080/health > /dev/null; then \
				if curl -s http://localhost:9000/hooks > /dev/null; then \
					status_msg 'Deployment verified successfully!' 'success' && \
					echo -e '\nServices are available at:' && \
					echo -e '  • App: http://'\$$HOST_IP':8080' && \
					echo -e '  • Webhook: http://'\$$HOST_IP':9000' && \
					echo -e '\nHealth check endpoints:' && \
					echo -e '  • App: http://'\$$HOST_IP':8080/health' && \
					echo -e '  • Webhook: http://'\$$HOST_IP':9000/hooks' && \
					exit 0; \
				fi; \
			fi; \
			RETRY_COUNT=\$$((RETRY_COUNT + 1)); \
			echo -n '.'; \
			sleep 5; \
		done; \
		status_msg 'Deployment verification failed' 'error' && \
		echo 'Checking container logs...' && \
		docker logs flow-control-app-1 && \
		docker logs flow-control-webhook-1 && \
		status_msg 'Attempting force cleanup and retry...' 'warning' && \
		$(MAKE) clean-env-force && \
		$(MAKE) staging || { \
			status_msg 'Final attempt failed after force cleanup' 'error'; \
			exit 1; \
		}"

staging: clean-env
	@bash -c ". $(PROGRESS_SCRIPT) && \
		show_logo && \
		status_msg 'Deploying to staging environment' 'info' && \
		docker compose -f docker-compose.staging.yml pull && \
		docker compose -f docker-compose.staging.yml up -d && \
		status_msg 'Staging deployment complete' 'success' && \
		$(MAKE) verify-staging"

setup-staging: clean-env
	@bash -c ". $(PROGRESS_SCRIPT) && \
		show_logo && \
		status_msg 'Initializing staging environment setup' 'info' && \
		if [ ! -f scripts/setup/setup-env.sh ]; then \
			status_msg 'setup-env.sh script not found' 'error'; \
			exit 1; \
		fi; \
		if [ ! -f scripts/common/init.sh ]; then \
			status_msg 'init.sh script not found' 'error'; \
			exit 1; \
		fi; \
		chmod +x scripts/setup/setup-env.sh scripts/common/init.sh && \
		status_msg 'Running setup script' 'info' && \
		bash -x scripts/setup/setup-env.sh \
			--env staging \
			--user deploy \
			--dir $(INSTALL_DIR) \
			--branch staging \
			--skip-memory-check && \
		$(MAKE) staging || { \
			status_msg 'Setup script failed' 'error'; \
			exit 1; \
		}"

logs:
	@docker compose -f docker-compose.staging.yml logs -f

dev: clean-env
	@bash -c ". $(PROGRESS_SCRIPT) && \
		show_logo && \
		status_msg 'Starting development server' 'info' && \
		docker compose up dev"

build:
	@echo "Building application..."
	@bash -c ". $(PROGRESS_SCRIPT) && \
		show_logo && \
		status_msg 'Starting build process' 'info' && \
		(docker compose run --rm test go build -o flow-control ./cmd/flowcontrol & progress_bar 30) && \
		complete_task 'Build complete!'"

run: check
	@echo "Starting application..."
	@bash -c ". $(PROGRESS_SCRIPT) && \
		show_logo && \
		status_msg 'Launching development server' 'info' && \
		docker compose up dev"

test:
	@echo "Running tests..."
	@bash -c ". $(PROGRESS_SCRIPT) && \
		show_logo && \
		status_msg 'Initializing test suite' 'info' && \
		(docker compose run --rm test go test ./... & progress_bar 20) && \
		complete_task 'Tests complete!'"

clean:
	@echo "Cleaning build artifacts..."
	@bash -c ". $(PROGRESS_SCRIPT) && \
		status_msg 'Cleaning workspace' 'info' && \
		rm -f flowcontrol && \
		rm -rf docs/ && \
		rm -rf tmp/ && \
		docker compose down -v && \
		complete_task 'Cleanup complete!'"

lint:
	@echo "Running linters..."
	@bash -c ". $(PROGRESS_SCRIPT) && \
		status_msg 'Starting code analysis' 'info' && \
		(docker compose run --rm test sh -c '\
			go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
			/go/bin/golangci-lint run' & progress_bar 15) && \
		complete_task 'Linting complete!'"

fmt:
	@echo "Formatting code..."
	@bash -c ". $(PROGRESS_SCRIPT) && \
		status_msg 'Formatting code' 'info' && \
		docker compose run --rm test sh -c 'go fmt ./...' && \
		complete_task 'Formatting complete!'"

check: fmt lint test
	@bash -c ". $(PROGRESS_SCRIPT) && \
		status_msg 'All checks passed!' 'success'"

install-tools:
	@bash -c ". $(PROGRESS_SCRIPT) && \
		show_logo && \
		status_msg 'Installing development tools' 'info' && \
		rm -f .git/hooks/pre-commit && \
		ln -s ../../scripts/pre-commit .git/hooks/pre-commit && \
		chmod +x scripts/pre-commit && \
		(docker compose run --rm test sh -c '\
			chmod +x scripts/tools/install-cli.sh && \
			./scripts/tools/install-cli.sh' & progress_bar 10) && \
		complete_task 'Tools installed successfully!'"

pre-commit: check
	@bash -c ". $(PROGRESS_SCRIPT) && \
		status_msg 'Pre-commit checks passed!' 'success'"

docker-test:
	@echo "Running Docker tests..."
	@bash -c ". $(PROGRESS_SCRIPT) && \
		show_logo && \
		status_msg 'Initializing Docker test suite' 'info' && \
		(docker compose run --rm test go test ./... & progress_bar 20) && \
		complete_task 'Docker tests complete!'"

docker-check:
	@echo "Running Docker checks..."
	@bash -c ". $(PROGRESS_SCRIPT) && \
		status_msg 'Starting Docker code analysis' 'info' && \
		(docker compose run --rm test sh -c '\
			go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
			/go/bin/golangci-lint run' & progress_bar 15) && \
		complete_task 'Docker code analysis complete!'"

help:
	@bash -c ". $(PROGRESS_SCRIPT) && \
		show_logo && \
		echo -e '\n${CYAN}Available targets:${NC}' && \
		echo '  make build       - Build the binary' && \
		echo '  make run        - Run the application' && \
		echo '  make test       - Run all tests' && \
		echo '  make lint       - Run linters' && \
		echo '  make fmt        - Format code' && \
		echo '  make check      - Run all checks' && \
		echo '  make clean      - Clean build artifacts' && \
		echo '  make install-tools - Install git hooks' && \
		echo '  make pre-commit - Run pre-commit checks' && \
		echo '  make dev        - Run development server' && \
		echo '  make staging    - Deploy to staging' && \
		echo '  make setup-staging - Set up staging environment' && \
		echo '  make help       - Show this help message'"