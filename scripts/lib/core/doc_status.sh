#!/bin/bash

# Documentation Status Manager
DOC_STATUS_FILE="README.md"
TEMP_FILE="/tmp/doc_status.tmp"

# Function to check component status
check_component_status() {
    local component=$1
    local status="❌ Not Started"
    local last_updated="-"
    local needs_review="-"

    # Add specific checks for each component
    case $component in
        "System Overview")
            if grep -q "## System Overview" "$DOC_STATUS_FILE"; then
                status="🟡 In Progress"
                last_updated=$(date +%Y-%m-%d)
                needs_review="Yes"
            fi
            ;;
        "Architecture Diagrams")
            if grep -q "mermaid" "$DOC_STATUS_FILE"; then
                status="🟡 In Progress"
                last_updated=$(date +%Y-%m-%d)
                needs_review="Yes"
            fi
            ;;
        "Core Components")
            if grep -q "## Core Components" "$DOC_STATUS_FILE"; then
                status="🟡 In Progress"
                last_updated=$(date +%Y-%m-%d)
                needs_review="Yes"
            fi
            ;;
        "API Documentation")
            if grep -q "## API Documentation" "$DOC_STATUS_FILE"; then
                status="🟡 In Progress"
                last_updated=$(date +%Y-%m-%d)
                needs_review="Yes"
            fi
            ;;
        "Database Schema")
            if grep -q "## Database Schema" "$DOC_STATUS_FILE"; then
                status="🟡 In Progress"
                last_updated=$(date +%Y-%m-%d)
                needs_review="Yes"
            fi
            ;;
        "Workflows")
            if grep -q "## Workflows" "$DOC_STATUS_FILE"; then
                status="🟡 In Progress"
                last_updated=$(date +%Y-%m-%d)
                needs_review="Yes"
            fi
            ;;
        "Glossary")
            if grep -q "## Glossary" "$DOC_STATUS_FILE"; then
                status="🟡 In Progress"
                last_updated=$(date +%Y-%m-%d)
                needs_review="Yes"
            fi
            ;;
    esac

    # Format the output with proper table alignment
    printf "%s | %s | %s | %s\n" \
        "$component" \
        "$status" \
        "$last_updated" \
        "$needs_review"
}

# Function to update documentation status
update_doc_status() {
    # Create status table header with badges
    cat > "$TEMP_FILE" << 'EOF'
# Project Documentation

## Documentation Status 📊

> Current documentation status and progress tracking

| Component | Status | Last Updated | Needs Review |
|-----------|--------|--------------|--------------|
EOF

    # Check and append status for each component
    while IFS= read -r component; do
        check_component_status "$component" >> "$TEMP_FILE"
    done << 'EOF'
System Overview
Architecture Diagrams
Core Components
API Documentation
Database Schema
Workflows
Glossary
EOF

    # Add status key with enhanced formatting
    cat >> "$TEMP_FILE" << 'EOF'

### Status Key

| Symbol | Meaning | Description |
|--------|---------|-------------|
| ✅ | Complete | Documentation is complete and verified |
| 🟡 | In Progress | Documentation is being actively updated |
| ❌ | Not Started | Documentation has not been initiated |
| 🔄 | Needs Update | Documentation requires revision |

EOF

    # Preserve the rest of the documentation after the status section
    sed -n '/^## Documentation Checklist/,$p' "$DOC_STATUS_FILE" >> "$TEMP_FILE"
    mv "$TEMP_FILE" "$DOC_STATUS_FILE"
}

# Function to check documentation completeness
check_doc_completeness() {
    local total=0
    local complete=0
    
    while IFS='|' read -r component status rest; do
        if [[ $component == *"Component"* ]]; then
            continue
        fi
        ((total++))
        if [[ $status == *"✅"* ]]; then
            ((complete++))
        fi
    done < <(grep "|" "$DOC_STATUS_FILE" | grep -v "^|--")

    echo "Documentation Progress: $complete/$total components complete ($(( (complete * 100) / total ))%)"
} 