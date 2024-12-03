#!/usr/bin/env bash

# Ensure we're running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash" >&2
    exit 1
fi

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/init.sh"
source "${SCRIPT_DIR}/../lib/progress/progress.sh"

# Show logo
show_logo

# Function to install a hook
install_hook() {
    local hook_name="$1"
    local source_path="$2"
    local target_path="$3"
    
    status_msg "Installing ${hook_name} hook..." "info"
    
    # Check if hook already exists
    if [ -f "$target_path" ]; then
        if [ -L "$target_path" ]; then
            status_msg "Hook already installed as symlink" "warning"
            return 0
        else
            status_msg "Backing up existing hook" "info"
            mv "$target_path" "${target_path}.backup"
        fi
    fi
    
    # Create symlink
    ln -sf "$source_path" "$target_path"
    chmod +x "$source_path"
    
    # Verify installation
    if [ -x "$target_path" ]; then
        status_msg "${hook_name} hook installed successfully" "success"
        return 0
    else
        status_msg "Failed to install ${hook_name} hook" "error"
        return 1
    fi
}

# Main function
main() {
    # Get project root directory
    local root_dir
    root_dir="$(git rev-parse --show-toplevel)"
    
    # Create hooks directory if it doesn't exist
    mkdir -p "${root_dir}/.git/hooks"
    
    # Install pre-commit hook
    install_hook "pre-commit" \
        "${root_dir}/scripts/pre-commit" \
        "${root_dir}/.git/hooks/pre-commit"
    
    # Final message
    if [ $? -eq 0 ]; then
        status_msg "Git hooks installed successfully! 🎉" "success"
        complete_task "Setup complete"
    else
        status_msg "Failed to install some hooks" "error"
        exit 1
    fi
}

# Run main function
main "$@" 