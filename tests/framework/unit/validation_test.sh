#!/bin/bash

# Unit Tests for Input Validation Library
source "${SCRIPT_DIR}/test/framework.sh"
source "${SCRIPT_DIR}/lib/core/validation.sh"

# Test setup
setup() {
    # Create test environment
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR" || exit 1
    
    # Create test files and directories
    mkdir -p test_dir
    touch test_file.txt
    chmod 755 test_file.txt
    
    # Create test environment variables
    export TEST_VAR="test_value"
}

# Test teardown
teardown() {
    cd - || exit 1
    rm -rf "$TEST_DIR"
    unset TEST_VAR
}

# Test input validation
test_validate_input() {
    # Test string validation
    assert_true "validate_input 'test' 'string'" "Valid string should pass"
    assert_false "validate_input '123' 'string'" "Number should fail string validation"
    
    # Test number validation
    assert_true "validate_input '123' 'number'" "Valid number should pass"
    assert_false "validate_input 'abc' 'number'" "Letters should fail number validation"
    
    # Test email validation
    assert_true "validate_input 'test@example.com' 'email'" "Valid email should pass"
    assert_false "validate_input 'invalid-email' 'email'" "Invalid email should fail"
    
    # Test URL validation
    assert_true "validate_input 'https://example.com' 'url'" "Valid URL should pass"
    assert_false "validate_input 'not-a-url' 'url'" "Invalid URL should fail"
    
    # Test custom pattern validation
    assert_true "validate_input 'abc123' '^[a-z0-9]+$'" "Valid pattern should pass"
    assert_false "validate_input 'ABC!' '^[a-z0-9]+$'" "Invalid pattern should fail"
}

# Test dependency checking
test_check_dependencies() {
    # Test single dependency
    assert_true "check_dependencies 'bash'" "Bash should be available"
    assert_false "check_dependencies 'non-existent-command'" "Non-existent command should fail"
    
    # Test multiple dependencies
    assert_true "check_dependencies 'bash ls grep'" "Common commands should be available"
    assert_false "check_dependencies 'bash non-existent ls'" "Should fail if any dependency is missing"
    
    # Test with version requirements
    assert_true "check_dependencies 'bash>=3.0'" "Bash version should meet requirement"
    assert_false "check_dependencies 'bash>=999.0'" "Impossible version should fail"
}

# Test environment validation
test_verify_environment() {
    # Test single variable
    assert_true "verify_environment 'TEST_VAR'" "Existing variable should pass"
    assert_false "verify_environment 'NON_EXISTENT_VAR'" "Non-existent variable should fail"
    
    # Test multiple variables
    assert_true "verify_environment 'TEST_VAR PATH'" "Common variables should exist"
    assert_false "verify_environment 'TEST_VAR NON_EXISTENT_VAR'" "Should fail if any variable is missing"
    
    # Test with required values
    assert_true "verify_environment 'TEST_VAR=test_value'" "Correct value should pass"
    assert_false "verify_environment 'TEST_VAR=wrong_value'" "Wrong value should fail"
}

# Test path validation
test_validate_path() {
    # Test file existence
    assert_true "validate_path 'test_file.txt' 'file'" "Existing file should pass"
    assert_false "validate_path 'non_existent.txt' 'file'" "Non-existent file should fail"
    
    # Test directory existence
    assert_true "validate_path 'test_dir' 'directory'" "Existing directory should pass"
    assert_false "validate_path 'non_existent_dir' 'directory'" "Non-existent directory should fail"
    
    # Test file permissions
    assert_true "validate_path 'test_file.txt' 'readable'" "Readable file should pass"
    assert_true "validate_path 'test_file.txt' 'writable'" "Writable file should pass"
    assert_true "validate_path 'test_file.txt' 'executable'" "Executable file should pass"
}

# Test network validation
test_validate_network() {
    # Test port availability
    assert_true "validate_network 'port' '8080'" "Unused port should pass"
    assert_false "validate_network 'port' '1'" "Privileged port should fail"
    
    # Test host connectivity
    assert_true "validate_network 'host' 'localhost'" "Localhost should be reachable"
    assert_false "validate_network 'host' 'non-existent-host'" "Non-existent host should fail"
    
    # Test URL accessibility
    assert_true "validate_network 'url' 'http://localhost'" "Local URL should be accessible"
    assert_false "validate_network 'url' 'http://non-existent-url'" "Non-existent URL should fail"
}

# Test permission validation
test_validate_permissions() {
    # Test file permissions
    touch test_file_perms.txt
    chmod 644 test_file_perms.txt
    
    assert_true "validate_permissions 'test_file_perms.txt' 'read'" "Should have read permission"
    assert_true "validate_permissions 'test_file_perms.txt' 'write'" "Should have write permission"
    assert_false "validate_permissions 'test_file_perms.txt' 'execute'" "Should not have execute permission"
    
    # Test directory permissions
    mkdir test_dir_perms
    chmod 755 test_dir_perms
    
    assert_true "validate_permissions 'test_dir_perms' 'read'" "Should have read permission"
    assert_true "validate_permissions 'test_dir_perms' 'write'" "Should have write permission"
    assert_true "validate_permissions 'test_dir_perms' 'execute'" "Should have execute permission"
}

# Run all tests
run_test_suite 