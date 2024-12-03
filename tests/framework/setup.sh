#!/bin/bash
set -e

# Install system dependencies
echo "Setting up test environment..."
apt-get update
apt-get install -y sqlite3 libsqlite3-dev gcc make git curl

# Install Go dependencies
echo "Installing Go dependencies..."
go mod download
go mod tidy 