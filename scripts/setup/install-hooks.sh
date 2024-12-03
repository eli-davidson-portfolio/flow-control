#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common utilities
source "$PROJECT_ROOT/scripts/lib/core/logging.sh"
source "$PROJECT_ROOT/scripts/lib/core/progress.sh"

# Install pre-commit hook
install_pre_commit() {
    log_header "Installing pre-commit hook"
    
    local hook_path="$PROJECT_ROOT/.git/hooks/pre-commit"
    local source_path="$PROJECT_ROOT/scripts/pre-commit"
    
    # Check if hook already exists
    if [ -f "$hook_path" ]; then
        if [ -L "$hook_path" ]; then
            log_info "Removing existing symlink"
            rm "$hook_path"
        else
            log_info "Backing up existing hook"
            mv "$hook_path" "${hook_path}.backup"
        fi
    fi
    
    # Create symlink
    ln -s "../../scripts/pre-commit" "$hook_path"
    chmod +x "$source_path"
    
    log_success "Pre-commit hook installed"
}

# Install other hooks as needed
install_other_hooks() {
    log_header "Installing other hooks"
    
    # Add other hook installations here
    # Example: pre-push, post-merge, etc.
    
    log_success "Other hooks installed"
}

# Main execution
main() {
    log_header "Installing Git hooks"
    
    # Install hooks
    install_pre_commit
    install_other_hooks
    
    log_success "All hooks installed successfully"
    log_info "Run 'git config core.hooksPath .git/hooks' to ensure hooks are used"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 