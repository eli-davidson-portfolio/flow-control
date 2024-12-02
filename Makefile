.PHONY: all build run test clean docs lint fmt check install-tools pre-commit dev docker-test docker-check setup-staging

# Server settings
SERVER_PORT=8080

all: check build

build:
	@echo "Building application..."
	@./scripts/build.sh
	@echo "Build complete!"

run: check
	@echo "Starting application..."
	@go run cmd/flowcontrol/main.go

# Test includes dependency management (go mod tidy)
test:
	@echo "Running tests (this may take a while)..."
	@./scripts/test.sh
	@echo "Tests complete!"

test-pkg:
	@echo "Testing package $(PKG)..."
	@./scripts/test.sh -p $(PKG)
	@echo "Package tests complete!"

clean:
	@echo "Cleaning build artifacts..."
	@rm -f flowcontrol
	@rm -rf docs/
	@rm -rf tmp/
	@docker compose down -v
	@echo "Clean complete!"

lint:
	@echo "Running linters (this may take a while)..."
	@./scripts/lint.sh
	@echo "Linting complete!"

fmt:
	@echo "Formatting code..."
	@./scripts/fmt.sh
	@echo "Formatting complete!"

check: fmt lint test
	@echo "All checks passed!"

install-tools:
	@echo "Installing development tools..."
	@cp scripts/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Tools installed successfully!"

pre-commit: check
	@echo "Running pre-commit checks..."
	@echo "Pre-commit checks passed!"

dev:
	@echo "Starting development server..."
	@docker compose up dev

# Docker environment tests
docker-test:
	@echo "Running Docker recovery tests..."
	@./scripts/test/docker-recovery.sh
	@echo "Docker recovery tests complete!"

# Quick Docker environment check
docker-check:
	@echo "Checking Docker environment..."
	@source scripts/common/docker-check.sh && ensure_docker_ready
	@echo "Docker environment check complete!"

# Full system check including Docker
system-check: docker-check check
	@echo "Full system check complete!"

# Staging setup
setup-staging:
	@echo "Setting up staging environment..."
	@if [ ! -f scripts/setup/setup-env.sh ]; then \
		echo "Error: setup-env.sh script not found"; \
		exit 1; \
	fi
	@if [ ! -f scripts/common/init.sh ]; then \
		echo "Error: init.sh script not found"; \
		exit 1; \
	fi
	chmod +x scripts/setup/setup-env.sh scripts/common/init.sh
	bash -x scripts/setup/setup-env.sh \
		--env staging \
		--user deploy \
		--dir /opt/flow-control \
		--branch staging \
		--skip-memory-check || { \
		echo "Error: Setup script failed. Check the error message above."; \
		exit 1; \
	}

help:
	@echo "Available targets:"
	@echo "  make build       - Build the binary"
	@echo "  make run        - Run the application"
	@echo "  make test       - Run all tests (includes dependency updates)"
	@echo "  make test-pkg PKG=./path/to/package - Run tests for a specific package"
	@echo "  make lint       - Run linters"
	@echo "  make fmt        - Format code"
	@echo "  make check      - Run all checks (fmt, lint, test)"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make install-tools - Install git hooks"
	@echo "  make pre-commit - Run pre-commit checks"
	@echo "  make dev        - Run development server"
	@echo "  make docker-test - Run Docker recovery tests"
	@echo "  make docker-check - Quick Docker environment check"
	@echo "  make system-check - Full system check including Docker"
	@echo "  make setup-staging - Set up the staging environment"
	@echo "  make help       - Show this help message"