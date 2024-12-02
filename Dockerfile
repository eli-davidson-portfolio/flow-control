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

# Production stage
FROM alpine:latest AS production

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache sqlite-dev curl

# Create necessary directories and user
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    mkdir -p data logs && \
    chown -R appuser:appgroup /app && \
    chmod 755 data logs

# Copy binary and documentation
COPY --from=builder /app/flow-control .
COPY --from=docs /app/docs ./docs
COPY web/ web/

# Ensure copied files have correct ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["./flow-control"] 