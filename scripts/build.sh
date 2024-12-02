#!/bin/bash
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common/init.sh"

generate_docs() {
    log_info "Generating API documentation..."
    
    # Ensure we're in the project root
    cd "$(git rev-parse --show-toplevel)"
    
    # Install swag if needed
    "${SCRIPT_DIR}/tools/install-cli.sh"
    
    # Generate docs with proper working directory
    if ! "${HOME}/go/bin/swag" init -g cmd/flowcontrol/main.go --parseDependency --parseInternal; then
        log_error "Failed to generate documentation"
        return 1
    fi
    
    log_info "Documentation generated successfully"
}

build_app() {
    log_info "Building application..."
    
    # Ensure dependencies are up to date
    go mod download
    go mod tidy
    
    # Build with CGO enabled for SQLite support
    CGO_ENABLED=1 go build -o flow-control ./cmd/flowcontrol
    
    log_info "Build complete!"
}

verify_build() {
    log_info "Verifying build..."
    
    if [[ ! -f "flow-control" ]]; then
        log_error "Build verification failed: Binary not found"
        return 1
    fi
    
    log_info "Build verified successfully"
}

main() {
    # Generate documentation
    if ! generate_docs; then
        return 1
    fi
    
    # Build the application
    if ! build_app; then
        return 1
    fi
    
    # Verify the build
    if ! verify_build; then
        return 1
    fi
    
    return 0
}

# Run main function
main "$@"
  