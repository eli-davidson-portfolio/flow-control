#!/bin/bash

# Run gosec security scanner
if ! command -v gosec &> /dev/null; then
    echo "Error: gosec not installed. Run: go install github.com/securego/gosec/v2/cmd/gosec@latest"
    exit 1
fi

# Run security scan
gosec ./...

# Check for hardcoded secrets
if grep -r "password\|secret\|key\|token" --exclude-dir={vendor,node_modules,.git} . | grep -v "Password\|Secret\|Key\|Token"; then
    echo "Error: Potential hardcoded secrets found"
    exit 1
fi

# Check for proper CORS configuration
if ! grep -r "cors.New" . > /dev/null; then
    echo "Warning: CORS middleware not found"
fi

# Check for authentication middleware
if ! grep -r "auth.Middleware" . > /dev/null; then
    echo "Warning: Authentication middleware not found"
fi

# Check for rate limiting
if ! grep -r "rate.Limiter" . > /dev/null; then
    echo "Warning: Rate limiting not implemented"
fi

# Check for secure headers
if ! grep -r "secure.Headers" . > /dev/null; then
    echo "Warning: Secure headers middleware not found"
fi

# Check for proper error handling
if grep -r "panic(" . --exclude-dir={vendor,node_modules,.git}; then
    echo "Error: Found panic() calls. Use proper error handling instead"
    exit 1
fi

# Check for proper logging
if ! grep -r "log.WithFields" . > /dev/null; then
    echo "Warning: Structured logging not implemented"
fi

# Check TLS configuration
if grep -r "InsecureSkipVerify" . --exclude-dir={vendor,node_modules,.git,tests}; then
    echo "Error: Found InsecureSkipVerify. Do not disable TLS verification"
    exit 1
fi

echo "Security validation passed" 