.PHONY: all build run test clean docs lint fmt check install-tools pre-commit

# Binary name
BINARY=flowcontrol
MAIN_PATH=cmd/flowcontrol/main.go

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

# Build flags
BUILD_FLAGS=-v

# Test flags
TEST_FLAGS=-v -race -count=1

all: check build

build: check docs
	$(GOBUILD) $(BUILD_FLAGS) -o $(BINARY) $(MAIN_PATH)

run: check
	$(GORUN) $(MAIN_PATH)

test: check
	$(GOTEST) $(TEST_FLAGS) ./...

clean:
	$(GOCLEAN)
	rm -f $(BINARY)
	rm -rf docs/

docs: ensure-swag
	@echo "Generating documentation..."
	$(SWAG) init -g $(MAIN_PATH) --parseDependency --parseInternal
	@echo "Documentation generated successfully"

lint: ensure-lint
	@echo "Running linters..."
	$(GOLANGCI_LINT) run
	@echo "Linting completed"

fmt:
	@echo "Formatting code..."
	$(GOFMT) -s -w .
	@echo "Formatting completed"

check: fmt lint test
	@echo "All checks passed!"

ensure-swag:
	@which swag > /dev/null || (echo "Installing swag..." && go install github.com/swaggo/swag/cmd/swag@latest)

ensure-lint:
	@which golangci-lint > /dev/null || (echo "Installing golangci-lint..." && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)

install-tools: ensure-swag ensure-lint
	@echo "Installing git hooks..."
	@cp scripts/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Tools installation complete"

pre-commit: check
	@echo "Pre-commit checks passed!"

# Watch for changes and regenerate docs
watch:
	@echo "Watching for changes..."
	@find . -name "*.go" | entr -r make docs

# Help target
help:
	@echo "Available targets:"
	@echo "  make build       - Build the binary (includes checks and docs)"
	@echo "  make run        - Run the application (includes checks)"
	@echo "  make test       - Run tests"
	@echo "  make docs       - Generate documentation"
	@echo "  make lint       - Run linters"
	@echo "  make fmt        - Format code"
	@echo "  make check      - Run all checks (fmt, lint, test)"
	@echo "  make watch      - Watch for changes and regenerate docs"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make install-tools - Install required tools and git hooks"
	@echo "  make pre-commit - Run pre-commit checks"
	@echo "  make help       - Show this help message" 