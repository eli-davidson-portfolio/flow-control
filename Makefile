# Use bash for shell commands
SHELL := /bin/bash

# Environment settings
INSTALL_DIR := $(shell pwd)
SCRIPTS_DIR := $(INSTALL_DIR)/scripts
LIB_DIR := $(SCRIPTS_DIR)/lib

# Source all library functions
export BASH_ENV := $(LIB_DIR)/env/utils.sh

.PHONY: all build run test clean lint fmt check install-tools pre-commit dev docker-test docker-check setup-staging verify-staging clean-env clean-env-force test-scripts

all: check build

# Run all script tests
test-scripts:
	@echo "Running script tests..."
	@for test in $(LIB_DIR)/test/*_test.sh; do \
		echo "\nRunning $$test"; \
		bash "$$test" || exit 1; \
	done

# Helper target for force cleanup
clean-env-force:
	@bash -c 'source $(LIB_DIR)/docker/manager.sh && docker_force_cleanup'

# Helper target to ensure clean environment
clean-env:
	@bash -c 'source $(LIB_DIR)/docker/manager.sh && \
		source $(LIB_DIR)/ports/manager.sh && \
		echo "Cleaning up environment..." && \
		docker_stop_all && \
		docker_remove_all && \
		docker_clean_networks'

# Helper target to ensure ports are free
ensure-ports:
	@bash -c 'source $(LIB_DIR)/ports/manager.sh && \
		free_ports 8080 9001 && \
		if ! wait_for_port 8080 10 2 || ! wait_for_port 9001 10 2; then \
			echo "Standard cleanup failed, attempting force cleanup..." && \
			docker_force_cleanup && \
			if ! wait_for_port 8080 10 2 || ! wait_for_port 9001 10 2; then \
				echo "Failed to free ports even after force cleanup" && \
				exit 1; \
			fi; \
		fi'

# Verify staging deployment
verify-staging:
	@bash -c 'source $(LIB_DIR)/env/utils.sh && \
		log_info "Verifying deployment..." && \
		echo "Waiting for services to initialize..." && \
		sleep 5 && \
		HOST_IP=$$(hostname -I | cut -d" " -f1) && \
		MAX_RETRIES=12 && \
		RETRY_COUNT=0 && \
		while [ $$RETRY_COUNT -lt $$MAX_RETRIES ]; do \
			if curl -s http://localhost:8080/health > /dev/null; then \
				if curl -s http://localhost:9000/hooks > /dev/null; then \
					log_info "Deployment verified successfully!" && \
					echo -e "\nServices are available at:" && \
					echo -e "  • App: http://$$HOST_IP:8080" && \
					echo -e "  • Webhook: http://$$HOST_IP:9000" && \
					echo -e "\nHealth check endpoints:" && \
					echo -e "  • App: http://$$HOST_IP:8080/health" && \
					echo -e "  • Webhook: http://$$HOST_IP:9000/hooks" && \
					exit 0; \
				fi; \
			fi; \
			RETRY_COUNT=$$((RETRY_COUNT + 1)); \
			echo -n "."; \
			sleep 5; \
		done; \
		log_error "Deployment verification failed" && \
		echo "Checking container logs..." && \
		docker logs flow-control-app-1 && \
		docker logs flow-control-webhook-1 && \
		log_warning "Attempting force cleanup and retry..." && \
		$(MAKE) clean-env-force && \
		$(MAKE) staging || { \
			log_error "Final attempt failed after force cleanup"; \
			exit 1; \
		}'

staging: clean-env ensure-ports
	@bash -c "source $(LIB_DIR)/env/utils.sh && \
		log_info 'Deploying to staging environment' && \
		docker compose -f docker-compose.staging.yml pull && \
		docker compose -f docker-compose.staging.yml up -d && \
		log_info 'Staging deployment complete' && \
		$(MAKE) verify-staging"

setup-staging: staging
	@bash -c 'source $(LIB_DIR)/env/utils.sh && \
		log_info "Initializing staging environment setup" && \
		if [ ! -f scripts/setup/setup-env.sh ]; then \
			log_error "setup-env.sh script not found"; \
			exit 1; \
		fi; \
		if [ ! -f scripts/common/init.sh ]; then \
			log_error "init.sh script not found"; \
			exit 1; \
		fi; \
		chmod +x scripts/setup/setup-env.sh scripts/common/init.sh && \
		log_info "Running setup script" && \
		bash -x scripts/setup/setup-env.sh \
			--env staging \
			--user deploy \
			--dir $(INSTALL_DIR) \
			--branch staging \
			--skip-memory-check || { \
			log_error "Setup script failed"; \
			exit 1; \
		}'

logs:
	@docker compose -f docker-compose.staging.yml logs -f

dev: clean-env
	@bash -c 'source $(LIB_DIR)/env/utils.sh && \
		log_info "Starting development server" && \
		docker compose up dev'

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