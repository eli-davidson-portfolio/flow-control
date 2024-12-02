# Documentation stage
FROM golang:1.22.1-alpine AS docs

WORKDIR /app

# Install build essentials and swag first for better caching
RUN apk add --no-cache git && \
    go install github.com/swaggo/swag/cmd/swag@latest

# Copy go mod files first and download dependencies
COPY go.mod go.sum ./
RUN go mod download && go mod tidy

# Copy only what's needed for docs
COPY cmd/ ./cmd/
COPY internal/ ./internal/

# Generate documentation
RUN /go/bin/swag init \
    --dir /app/cmd/flowcontrol \
    --generalInfo main.go \
    --propertyStrategy camelcase \
    --output /app/docs \
    --parseInternal \
    --parseDependency

# Build stage
FROM golang:1.22.1-alpine AS builder

WORKDIR /app

# Install build dependencies first for better caching
RUN apk add --no-cache gcc musl-dev sqlite-dev

# Copy go mod files first and download dependencies
COPY go.mod go.sum ./
RUN go mod download && go mod tidy

# Copy source code
COPY . .

# Copy generated docs
COPY --from=docs /app/docs/ ./docs/

# Build the application with optimizations
RUN CGO_ENABLED=1 go build \
    -ldflags="-w -s" \
    -o flow-control ./cmd/flowcontrol

# Development stage with hot reload
FROM golang:1.22.1-alpine AS dev

WORKDIR /app

# Install development tools
RUN apk add --no-cache git && \
    go install github.com/cosmtrek/air@latest

# Copy source code and generated docs
COPY . .
COPY --from=docs /app/docs/ ./docs/

CMD ["air"]

# Test stage
FROM golang:1.22.1-alpine AS test

WORKDIR /app

# Install build dependencies and tools
RUN apk add --no-cache gcc musl-dev sqlite-dev git curl && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Copy source code and generated docs
COPY . .
COPY --from=docs /app/docs/ ./docs/

CMD ["go", "test", "./..."]

# Production stage
FROM alpine:latest AS production

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache sqlite-dev

# Copy binary and documentation
COPY --from=builder /app/flow-control .
COPY --from=docs /app/docs ./docs
COPY web/ web/

# Create necessary directories
RUN mkdir -p data logs

EXPOSE 8080

CMD ["./flow-control"] 