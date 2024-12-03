#!/bin/bash

# Unit Tests for Configuration Management Library
source "${SCRIPT_DIR}/test/framework.sh"
source "${SCRIPT_DIR}/lib/core/config.sh"

# Test setup
setup() {
    # Create test configuration directory
    TEST_CONFIG_DIR=$(mktemp -d)
    
    # Create test configuration files
    cat > "$TEST_CONFIG_DIR/default.conf" << EOF
# Default settings
APP_NAME="TestApp"
VERSION="1.0.0"
DEBUG=false
PORT=8080
EOF
    
    cat > "$TEST_CONFIG_DIR/dev.conf" << EOF
# Development overrides
DEBUG=true
PORT=3000
EOF
    
    cat > "$TEST_CONFIG_DIR/local.conf" << EOF
# Local overrides
PORT=5000
CUSTOM_VAR="local_value"
EOF
    
    # Set environment variables
    export CONFIG_DIR="$TEST_CONFIG_DIR"
    export ENVIRONMENT="dev"
}

# Test teardown
teardown() {
    rm -rf "$TEST_CONFIG_DIR"
    unset CONFIG_DIR ENVIRONMENT
}

# Test configuration loading
test_load_config() {
    # Test default config loading
    load_config
    assert_equals "TestApp" "$(get_config_value 'APP_NAME')" "Should load default app name"
    assert_equals "1.0.0" "$(get_config_value 'VERSION')" "Should load default version"
    
    # Test environment override
    assert_equals "true" "$(get_config_value 'DEBUG')" "Should override debug from dev config"
    assert_equals "3000" "$(get_config_value 'PORT')" "Should override port from dev config"
    
    # Test local override
    assert_equals "5000" "$(get_config_value 'PORT')" "Should override port from local config"
    assert_equals "local_value" "$(get_config_value 'CUSTOM_VAR')" "Should load local custom variable"
}

# Test environment-specific loading
test_environment_loading() {
    # Test development environment
    export ENVIRONMENT="dev"
    load_config
    assert_equals "true" "$(get_config_value 'DEBUG')" "Should load dev debug setting"
    
    # Test production environment
    export ENVIRONMENT="prod"
    load_config
    assert_equals "false" "$(get_config_value 'DEBUG')" "Should load default debug setting"
}

# Test configuration value retrieval
test_get_config_value() {
    load_config
    
    # Test existing values
    assert_equals "TestApp" "$(get_config_value 'APP_NAME')" "Should get existing value"
    
    # Test default values
    assert_equals "default" "$(get_config_value 'NON_EXISTENT' 'default')" "Should return default for missing key"
    
    # Test empty values
    assert_equals "" "$(get_config_value 'NON_EXISTENT')" "Should return empty for missing key without default"
}

# Test configuration value setting
test_set_config_value() {
    load_config
    
    # Test setting new value
    set_config_value "NEW_KEY" "new_value"
    assert_equals "new_value" "$(get_config_value 'NEW_KEY')" "Should set new value"
    
    # Test overwriting existing value
    set_config_value "APP_NAME" "NewApp"
    assert_equals "NewApp" "$(get_config_value 'APP_NAME')" "Should override existing value"
    
    # Test setting value in specific file
    set_config_value "CUSTOM_KEY" "custom_value" "local.conf"
    assert_true "grep -q '^CUSTOM_KEY=\"custom_value\"$' '$TEST_CONFIG_DIR/local.conf'" "Should write to specific file"
}

# Test configuration validation
test_validate_config() {
    # Test required keys
    assert_true "validate_config 'APP_NAME VERSION'" "Should validate existing required keys"
    assert_false "validate_config 'APP_NAME NON_EXISTENT'" "Should fail on missing required key"
    
    # Test value constraints
    assert_true "validate_config_value 'PORT' '^[0-9]+$'" "Should validate numeric port"
    assert_false "validate_config_value 'APP_NAME' '^[0-9]+$'" "Should fail non-numeric app name"
}

# Test configuration inheritance
test_config_inheritance() {
    # Create test environment config
    cat > "$TEST_CONFIG_DIR/staging.conf" << EOF
# Staging inherits from dev
inherit=dev.conf
HOST="staging.example.com"
EOF
    
    # Test inheritance chain
    export ENVIRONMENT="staging"
    load_config
    
    assert_equals "true" "$(get_config_value 'DEBUG')" "Should inherit debug from dev"
    assert_equals "staging.example.com" "$(get_config_value 'HOST')" "Should have staging-specific value"
}

# Test configuration backup/restore
test_config_backup_restore() {
    # Create backup
    backup_config
    assert_true "[[ -f '$TEST_CONFIG_DIR/backup/default.conf' ]]" "Should create backup of default config"
    
    # Modify configuration
    set_config_value "APP_NAME" "ModifiedApp"
    
    # Restore backup
    restore_config
    assert_equals "TestApp" "$(get_config_value 'APP_NAME')" "Should restore original value"
}

# Test configuration migration
test_config_migration() {
    # Create old format config
    cat > "$TEST_CONFIG_DIR/old.conf" << EOF
app.name=TestApp
app.version=1.0.0
EOF
    
    # Migrate configuration
    migrate_config "$TEST_CONFIG_DIR/old.conf" "$TEST_CONFIG_DIR/new.conf"
    
    # Verify migration
    assert_true "grep -q '^APP_NAME=\"TestApp\"$' '$TEST_CONFIG_DIR/new.conf'" "Should migrate app name"
    assert_true "grep -q '^VERSION=\"1.0.0\"$' '$TEST_CONFIG_DIR/new.conf'" "Should migrate version"
}

# Run all tests
run_test_suite 