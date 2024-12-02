# Documentation stage
FROM golang:1.22.1-alpine AS docs

WORKDIR /app

# Install swag
RUN go install github.com/swaggo/swag/cmd/swag@latest

# Copy only what's needed for docs
COPY go.mod go.sum ./
COPY cmd/ ./cmd/
COPY internal/ ./internal/
COPY pkg/ ./pkg/

# Generate documentation
RUN cd /app && \
    go mod download && \
    go mod tidy && \
    /go/bin/swag init \
        --dir /app/cmd/flowcontrol \
        --generalInfo main.go \
        --propertyStrategy camelcase \
        --output /app/docs \
        --parseInternal \
        --parseDependency

# Build stage
FROM golang:1.22.1-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache gcc musl-dev sqlite-dev

# Copy go mod files and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and generated docs
COPY . .
COPY --from=docs /app/docs/ ./docs/

# Build the application
RUN go build -o flow-control ./cmd/flowcontrol

# Development stage with hot reload
FROM golang:1.22.1-alpine AS dev

WORKDIR /app

RUN go install github.com/cosmtrek/air@latest

COPY . .
COPY --from=docs /app/docs/ ./docs/

CMD ["air"]

# Test stage
FROM golang:1.22.1-alpine AS test

WORKDIR /app

# Install build dependencies and tools
RUN apk add --no-cache gcc musl-dev sqlite-dev git curl && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

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

RUN mkdir -p data logs

EXPOSE 8080

CMD ["./flow-control"] 