# Environment parameters
ENV_DEV=dev
ENV_STAGING=staging
VERIFY_DIR=scripts/verify
DOCKER_COMPOSE=docker compose
DOCKER_COMPOSE_DEV=$(DOCKER_COMPOSE) -f config/dev/docker-compose.yml
DOCKER_COMPOSE_STAGING=$(DOCKER_COMPOSE) -f config/staging/docker-compose.staging.yml

# Directory structure
BUILD_DIR=build
BIN_DIR=bin
DATA_DIR=data
LOG_DIR=logs
BACKUP_DIR=backups
CONFIG_DIR=config
COVERAGE_DIR=coverage
TEST_DIR=tests
SCRIPT_DIR=scripts

# Build parameters
BINARY_NAME=flow-control
GO_FILES=$(shell find . -name '*.go' -not -path "./vendor/*")
VERSION=$(shell git describe --tags --always --dirty)
GO_VERSION=$(shell go version | cut -d' ' -f3 | sed 's/go//')

# Test parameters
FAIL_FAST=true
TEST_TIMEOUT=5m
COVERAGE_PROFILE=$(COVERAGE_DIR)/coverage.out
COVERAGE_HTML=$(COVERAGE_DIR)/coverage.html

# Build targets
.PHONY: all dev staging verify-dev verify-staging test clean docker-clean docker-prune audit audit-all audit-structure audit-quality audit-code verify-all

# Verification targets
verify-all: verify-dev audit-all test
	@echo "All verifications completed successfully"

# Development environment
verify-dev:
	@echo "Verifying development environment..."
	@ENVIRONMENT=$(ENV_DEV) $(VERIFY_DIR)/dev_checks.sh

# Audit targets
audit-structure:
	@echo "Running project structure audit..."
	@$(SCRIPT_DIR)/audit/project_structure.sh

audit-quality:
	@echo "Running code quality audit..."
	@$(SCRIPT_DIR)/audit/code_quality.sh

audit-code:
	@echo "Running code usage audit..."
	@$(SCRIPT_DIR)/audit/code_usage.sh

audit: audit-structure audit-quality audit-code
	@echo "All audits completed. Check docs/ directory for reports."

audit-all: audit test-coverage
	@echo "Full project audit completed."

# Testing targets
test-setup:
	@echo "Setting up test environment..."
	@mkdir -p $(COVERAGE_DIR)
	@mkdir -p $(DATA_DIR)
	@mkdir -p $(LOG_DIR)/tests

test: test-setup
	@echo "Running all tests..."
	@FAIL_FAST=$(FAIL_FAST) $(TEST_DIR)/framework/run_all.sh

test-level-%: test-setup
	@echo "Running tests for level $*..."
	@FAIL_FAST=$(FAIL_FAST) $(TEST_DIR)/framework/run_level.sh $*

test-unit: test-setup
	@echo "Running unit tests..."
	@go test -v -timeout $(TEST_TIMEOUT) -coverprofile=$(COVERAGE_PROFILE) ./internal/... ./pkg/...
	@go tool cover -html=$(COVERAGE_PROFILE) -o $(COVERAGE_HTML)

test-integration: test-setup
	@echo "Running integration tests..."
	@$(DOCKER_COMPOSE) run --rm test go test -v -tags=integration ./tests/integration/...

test-coverage: test-setup
	@echo "Running tests with coverage..."
	@go test -v -coverprofile=$(COVERAGE_PROFILE) ./...
	@go tool cover -html=$(COVERAGE_PROFILE) -o $(COVERAGE_HTML)
	@go tool cover -func=$(COVERAGE_PROFILE)

test-audit:
	@echo "Running code usage audit..."
	@$(SCRIPT_DIR)/audit/code_usage.sh

# Main development target
dev: verify-all
	@echo "Starting development environment..."
	@echo "Creating required directories..." && \
	mkdir -p $(DATA_DIR) $(LOG_DIR) $(BACKUP_DIR) && \
	echo "Starting Docker services..." && \
	$(DOCKER_COMPOSE_DEV) up --build -d && \
	echo "Waiting for services to be healthy..." && \
	$(DOCKER_COMPOSE_DEV) logs -f dev & \
	until $(DOCKER_COMPOSE_DEV) exec dev curl -s http://localhost:8081/health >/dev/null; do \
		sleep 1; \
	done && \
	echo "Development environment is ready!" && \
	echo "API: http://localhost:8081" && \
	echo "Webhook: http://localhost:9001" && \
	echo "Logs: tail -f $(LOG_DIR)/dev.log" && \
	$(DOCKER_COMPOSE_DEV) logs -f

# Staging environment
verify-staging:
	@echo "Verifying staging environment..."
	@ENVIRONMENT=$(ENV_STAGING) $(VERIFY_DIR)/staging_checks.sh

staging: verify-staging
	@echo "Starting staging environment..."
	@if [ $$? -eq 0 ]; then \
		echo "Creating required directories..." && \
		mkdir -p $(DATA_DIR) $(LOG_DIR) $(BACKUP_DIR) && \
		echo "Building production images..." && \
		$(DOCKER_COMPOSE_STAGING) build --no-cache && \
		echo "Starting services..." && \
		$(DOCKER_COMPOSE_STAGING) up -d && \
		echo "Waiting for services to be healthy..." && \
		until $(DOCKER_COMPOSE_STAGING) exec app curl -s http://localhost:8080/health >/dev/null; do \
			sleep 1; \
		done && \
		echo "Staging environment is ready!" && \
		echo "API: http://localhost:8080" && \
		echo "Webhook: http://localhost:9001" && \
		echo "Logs: tail -f $(LOG_DIR)/staging.log" && \
		$(DOCKER_COMPOSE_STAGING) logs -f; \
	else \
		echo "Environment verification failed. Please fix the issues and try again."; \
		exit 1; \
	fi

# Cleanup targets
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(BIN_DIR)
	@rm -rf $(COVERAGE_DIR)
	@rm -f go.sum

docker-clean:
	@echo "Stopping and removing containers..."
	@$(DOCKER_COMPOSE) down -v
	@$(DOCKER_COMPOSE_STAGING) down -v

docker-prune:
	@echo "Pruning Docker system..."
	@docker system prune -f

# Development utilities
logs:
	@echo "Showing logs..."
	@$(DOCKER_COMPOSE) logs -f

ps:
	@echo "Showing running containers..."
	@$(DOCKER_COMPOSE) ps

restart:
	@echo "Restarting services..."
	@$(DOCKER_COMPOSE) restart

rebuild:
	@echo "Rebuilding services..."
	@$(DOCKER_COMPOSE) build --no-cache
	@$(DOCKER_COMPOSE) up -d

shell:
	@echo "Opening shell in development container..."
	@$(DOCKER_COMPOSE) exec dev /bin/bash

test-shell:
	@echo "Opening shell in test container..."
	@$(DOCKER_COMPOSE) exec test /bin/bash