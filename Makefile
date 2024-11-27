.PHONY: all build run test clean docs lint fmt check install-tools pre-commit dev dev-full kill-server

# Binary name
BINARY=flowcontrol
MAIN_PATH=cmd/flowcontrol/main.go

# Docker commands
DOCKER_COMPOSE=docker compose
DOCKER_RUN=$(DOCKER_COMPOSE) run -T --rm test

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GORUN=$(GOCMD) run
GOTEST=$(GOCMD) test
GOCLEAN=$(GOCMD) clean
GOFMT=gofmt

# Tool binaries
SWAG=swag
GOLANGCI_LINT=golangci-lint
AIR=air

# Server settings
SERVER_PORT=8080

# Build flags
BUILD_FLAGS=-v
TEST_FLAGS=-v -race -count=1

# Alpine packages
ALPINE_PACKAGES=gcc musl-dev sqlite-dev binutils binutils-gold

# SQLite flags
export CGO_ENABLED=1
export CGO_CFLAGS=-D_FILE_OFFSET_BITS=64

all: check build

build: check docs
	$(GOBUILD) $(BUILD_FLAGS) -o $(BINARY) $(MAIN_PATH)

run: check
	$(GORUN) $(MAIN_PATH)

test:
	$(DOCKER_RUN) sh -c "apk add --no-cache $(ALPINE_PACKAGES) && CGO_ENABLED=1 CGO_CFLAGS='-D_FILE_OFFSET_BITS=64' go test -v ./..."

clean:
	$(GOCLEAN)
	rm -f $(BINARY)
	rm -rf docs/
	rm -rf tmp/
	docker compose down -v

docs: ensure-swag
	@echo "Generating documentation..."
	$(SWAG) init -g $(MAIN_PATH) --parseDependency --parseInternal
	@echo "Documentation generated successfully"

lint:
	@echo "Running linters in Docker..."
	$(DOCKER_RUN) sh -c "apk add --no-cache $(ALPINE_PACKAGES) && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && golangci-lint run"
	@echo "Linting completed"

fmt:
	@echo "Formatting code in Docker..."
	$(DOCKER_RUN) sh -c "apk add --no-cache $(ALPINE_PACKAGES) && gofmt -s -w ."
	@echo "Formatting completed"

check: fmt lint test
	@echo "All checks passed!"

ensure-swag:
	@which swag > /dev/null || (echo "Installing swag..." && go install github.com/swaggo/swag/cmd/swag@latest)

install-tools: ensure-swag
	@echo "Installing git hooks..."
	@cp scripts/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Tools installation complete"

pre-commit: check
	@echo "Pre-commit checks passed!"

# Development targets
dev:
	@echo "Starting development server with hot reload..."
	$(DOCKER_COMPOSE) up dev

dev-full: check docs dev
	@echo "Starting development server with full checks..."

# Kill any process running on the server port
kill-server:
	@echo "Checking for processes on port $(SERVER_PORT)..."
	@if [ -n "$$(lsof -ti :$(SERVER_PORT))" ]; then \
		echo "Found process on port $(SERVER_PORT), attempting graceful shutdown..."; \
		lsof -ti :$(SERVER_PORT) | xargs kill 2>/dev/null || true; \
		sleep 2; \
		if [ -n "$$(lsof -ti :$(SERVER_PORT))" ]; then \
			echo "Process still running, forcing termination..."; \
			lsof -ti :$(SERVER_PORT) | xargs kill -9 2>/dev/null || true; \
		fi \
	fi

# Help target
help:
	@echo "Available targets:"
	@echo "  make build       - Build the binary (includes checks and docs)"
	@echo "  make run        - Run the application (includes checks)"
	@echo "  make dev        - Run the application with hot reload in Docker"
	@echo "  make dev-full   - Run the application with hot reload and full checks"
	@echo "  make test       - Run tests in Docker"
	@echo "  make docs       - Generate documentation"
	@echo "  make lint       - Run linters in Docker"
	@echo "  make fmt        - Format code in Docker"
	@echo "  make check      - Run all checks in Docker (fmt, lint, test)"
	@echo "  make clean      - Clean build artifacts and stop containers"
	@echo "  make install-tools - Install required tools and git hooks"
	@echo "  make pre-commit - Run pre-commit checks"
	@echo "  make help       - Show this help message"