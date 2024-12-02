#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/init.sh"

install_swag_cli() {
    echo "Checking swag CLI installation..."
    if ! command -v swag > /dev/null; then
        echo "Installing swag CLI..."
        go install github.com/swaggo/swag/cmd/swag@latest
        export PATH="${HOME}/go/bin:${PATH}"
    else
        echo "swag CLI already installed"
    fi
}

# Main execution
install_swag_cli 