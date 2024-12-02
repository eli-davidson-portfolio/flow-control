#!/bin/bash
set -e

echo "Formatting code..."
find . -name "*.go" -not -path "./vendor/*" -not -path "./.git/*" -exec gofmt -s -w {} \; 