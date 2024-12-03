#!/bin/bash

# Check for required documentation files
REQUIRED_DOCS=(
    "README.md"
    "docs/architecture.md"
    "docs/api.md"
    "docs/deployment.md"
    "docs/development.md"
)

for doc in "${REQUIRED_DOCS[@]}"; do
    if [ ! -f "$doc" ]; then
        echo "Error: Required documentation '$doc' is missing"
        exit 1
    fi
done

# Check API documentation coverage
if ! command -v swag &> /dev/null; then
    echo "Error: swag not installed. Run: go install github.com/swaggo/swag/cmd/swag@latest"
    exit 1
fi

# Generate Swagger docs
swag init -g cmd/flow-control/main.go

# Check if all handlers have Swagger annotations
HANDLERS=$(grep -r "@Router" . | wc -l)
ENDPOINTS=$(grep -r "func.*http.HandlerFunc" . | wc -l)

if [ "$HANDLERS" -lt "$ENDPOINTS" ]; then
    echo "Error: Not all endpoints are documented with Swagger annotations"
    echo "Found $HANDLERS documented endpoints out of $ENDPOINTS total endpoints"
    exit 1
fi

# Check README.md sections
REQUIRED_SECTIONS=(
    "Installation"
    "Configuration"
    "Usage"
    "Development"
    "Contributing"
)

for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "^## $section" README.md; then
        echo "Error: README.md missing required section '$section'"
        exit 1
    fi
done

# Check godoc coverage
go doc -all ./... | while read -r line; do
    if [[ $line =~ ^func|^type|^var|^const && ! $line =~ ^// ]]; then
        echo "Error: Missing documentation for: $line"
        exit 1
    fi
done

echo "Documentation validation passed" 