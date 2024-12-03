#!/bin/bash

# Required directories
REQUIRED_DIRS=(
    "cmd"
    "internal"
    "pkg"
    "docs"
    "scripts"
    "tests"
)

# Required files
REQUIRED_FILES=(
    "go.mod"
    "README.md"
    "Makefile"
    ".golangci.yml"
)

# Check required directories
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Error: Required directory '$dir' is missing"
        exit 1
    fi
done

# Check required files
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required file '$file' is missing"
        exit 1
    fi
done

# Check for duplicate packages
find . -type d -name "flow-control" | while read -r dir; do
    count=$(find . -type d -name "flow-control" | wc -l)
    if [ "$count" -gt 1 ]; then
        echo "Error: Multiple 'flow-control' directories found"
        exit 1
    fi
done

# Validate go files have proper package documentation
find . -name "*.go" -not -path "./vendor/*" | while read -r file; do
    if ! grep -q "^// Package .* " "$file" && ! grep -q "^package main$" "$file"; then
        echo "Error: Missing package documentation in $file"
        exit 1
    fi
done

echo "Project structure validation passed" 