.PHONY: all build run test clean lint fmt check install-tools pre-commit dev docker-test docker-check setup-staging

# Server settings
SERVER_PORT=8080

all: check build

build:
	@echo "Building application..."
	@source scripts/common/progress.sh && \
		show_logo && \
		status_msg "Starting build process" "info" && \
		matrix_rain 1 && \
		(docker compose run --rm test go build -o flow-control ./cmd/flowcontrol & progress_bar 30) && \
		complete_task "Build complete!"

run: check
	@echo "Starting application..."
	@source scripts/common/progress.sh && \
		show_logo && \
		status_msg "Launching development server" "info" && \
		docker compose up dev

test:
	@echo "Running tests..."
	@source scripts/common/progress.sh && \
		show_logo && \
		status_msg "Initializing test suite" "info" && \
		matrix_rain 1 && \
		(docker compose run --rm test go test ./... & progress_bar 20) && \
		complete_task "Tests complete!"

clean:
	@echo "Cleaning build artifacts..."
	@source scripts/common/progress.sh && \
		status_msg "Cleaning workspace" "info" && \
		rm -f flowcontrol && \
		rm -rf docs/ && \
		rm -rf tmp/ && \
		docker compose down -v && \
		complete_task "Cleanup complete!"

lint:
	@echo "Running linters..."
	@source scripts/common/progress.sh && \
		status_msg "Starting code analysis" "info" && \
		(docker compose run --rm test sh -c "\
			go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
			/go/bin/golangci-lint run" & progress_bar 15) && \
		complete_task "Linting complete!"

fmt:
	@echo "Formatting code..."
	@source scripts/common/progress.sh && \
		status_msg "Formatting code" "info" && \
		docker compose run --rm test sh -c "go fmt ./..." && \
		complete_task "Formatting complete!"

check: fmt lint test
	@source scripts/common/progress.sh && \
		status_msg "All checks passed!" "success"

install-tools:
	@source scripts/common/progress.sh && \
		show_logo && \
		status_msg "Installing development tools" "info" && \
		rm -f .git/hooks/pre-commit && \
		ln -s ../../scripts/pre-commit .git/hooks/pre-commit && \
		chmod +x scripts/pre-commit && \
		(docker compose run --rm test sh -c "\
			chmod +x scripts/tools/install-cli.sh && \
			./scripts/tools/install-cli.sh" & progress_bar 10) && \
		complete_task "Tools installed successfully!"

pre-commit: check
	@source scripts/common/progress.sh && \
		status_msg "Pre-commit checks passed!" "success"

dev:
	@source scripts/common/progress.sh && \
		show_logo && \
		status_msg "Starting development server" "info" && \
		docker compose up dev

staging:
	@source scripts/common/progress.sh && \
		show_logo && \
		status_msg "Deploying to staging environment" "info" && \
		matrix_rain 2 && \
		docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d && \
		status_msg "Staging deployment complete" "success" && \
		echo "Following logs in real-time (Ctrl+C to stop viewing logs)..." && \
		docker compose -f docker-compose.yml -f docker-compose.staging.yml logs -f

setup-staging:
	@source scripts/common/progress.sh && \
		show_logo && \
		status_msg "Initializing staging environment setup" "info" && \
		if [ ! -f scripts/setup/setup-env.sh ]; then \
			status_msg "setup-env.sh script not found" "error"; \
			exit 1; \
		fi; \
		if [ ! -f scripts/common/init.sh ]; then \
			status_msg "init.sh script not found" "error"; \
			exit 1; \
		fi; \
		chmod +x scripts/setup/setup-env.sh scripts/common/init.sh && \
		matrix_rain 2 && \
		status_msg "Running setup script" "info" && \
		bash -x scripts/setup/setup-env.sh \
			--env staging \
			--user deploy \
			--dir /opt/flow-control \
			--branch staging \
			--skip-memory-check || { \
			status_msg "Setup script failed" "error"; \
			exit 1; \
		}

help:
	@source scripts/common/progress.sh && \
		show_logo && \
		echo -e "\n${CYAN}Available targets:${NC}" && \
		echo "  make build       - Build the binary" && \
		echo "  make run        - Run the application" && \
		echo "  make test       - Run all tests" && \
		echo "  make lint       - Run linters" && \
		echo "  make fmt        - Format code" && \
		echo "  make check      - Run all checks" && \
		echo "  make clean      - Clean build artifacts" && \
		echo "  make install-tools - Install git hooks" && \
		echo "  make pre-commit - Run pre-commit checks" && \
		echo "  make dev        - Run development server" && \
		echo "  make staging    - Deploy to staging" && \
		echo "  make setup-staging - Set up staging environment" && \
		echo "  make help       - Show this help message"