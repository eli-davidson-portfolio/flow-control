#!/bin/bash

set -e  # Exit on error

# Main documentation update script
echo "Loading doc_status.sh..."
source scripts/lib/core/doc_status.sh

echo "Loading doc_analyzer.sh..."
source scripts/lib/core/doc_analyzer.sh

# Check if we need to migrate from NOTES.md
if [ -f "NOTES.md" ] && [ ! -f "README.md" ]; then
    echo "Migrating NOTES.md to README.md..."
    cp "NOTES.md" "README.md"
elif [ -f "NOTES.md" ]; then
    echo "Warning: NOTES.md exists. This script now updates README.md instead."
    echo "You may want to merge any content from NOTES.md into README.md"
    echo
fi

# Create initial documentation structure if it doesn't exist
if [ ! -f "$DOC_STATUS_FILE" ]; then
    echo "Creating initial README.md structure..."
    cat > "$DOC_STATUS_FILE" << 'EOF'
# Project Documentation

## Documentation Status

## Documentation Checklist

## System Overview
A comprehensive documentation of the entire codebase and its components.

### Purpose
This documentation provides a complete overview of the project structure, components, and functionality.

### Key Features
- Automated documentation generation
- Status tracking and progress monitoring
- Code analysis and documentation extraction
- Component relationship mapping

## Architecture
### High-Level System Architecture

## Core Components

## API Documentation

## Database Schema

## Go Dependencies

## Configuration

## Project Requirements

## Glossary

## Documentation Management
### Automatic Documentation Tools
The following tools are used to maintain this documentation:

- `scripts/update_docs.sh`: Main documentation update script
  - Updates documentation status
  - Runs code analysis
  - Maintains document structure
  
- `scripts/lib/core/doc_status.sh`: Documentation status tracker
  - Tracks component completion status
  - Monitors documentation progress
  - Validates documentation requirements
  
- `scripts/lib/core/doc_analyzer.sh`: Source code analyzer
  - Analyzes Go dependencies
  - Documents shell scripts
  - Processes project requirements

### Usage
To update this documentation:

```bash
./scripts/update_docs.sh
```

This will:
1. Update the documentation status
2. Analyze all source files
3. Update project requirements
4. Check documentation completeness

EOF
fi

# Update documentation status
echo "Updating documentation status..."
update_doc_status

# Run analyzers in specific order
echo "Running documentation analyzers..."

# Create a temporary file for building the documentation
TEMP_DOC=$(mktemp)

# Start with the status and checklist sections
sed '/^## Go Dependencies/q' "$DOC_STATUS_FILE" > "$TEMP_DOC"

# Add each section in the correct order
analyze_go_mod && echo "✅ Go dependencies analyzed" || echo "⚠️ No go.mod found"
analyze_config && echo "✅ Configuration analyzed" || echo "⚠️ No config.sh found"
analyze_project_requirements && echo "✅ Project requirements analyzed" || echo "⚠️ No project.txt found"

# Add remaining sections
sed -n '/^## Documentation Management/,$p' "$DOC_STATUS_FILE" >> "$TEMP_DOC"

# Replace the original file
mv "$TEMP_DOC" "$DOC_STATUS_FILE"

# Check documentation completeness
echo "Checking documentation completeness..."
check_doc_completeness

# Clean up any duplicate sections
echo "Cleaning up documentation..."
awk '!seen[$0]++' "$DOC_STATUS_FILE" > "${DOC_STATUS_FILE}.tmp" && mv "${DOC_STATUS_FILE}.tmp" "$DOC_STATUS_FILE"

# Ensure proper spacing between sections (cross-platform compatible)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS version
    sed -i '' -e '/^##[^#]/i\
' "$DOC_STATUS_FILE"
else
    # Linux version
    sed -i -e '/^##[^#]/i\\' "$DOC_STATUS_FILE"
fi

echo "Documentation updated successfully!"