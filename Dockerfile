# Build stage
FROM golang:1.22.1-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache gcc musl-dev sqlite-dev

# Install swag for API documentation
RUN go install github.com/swaggo/swag/cmd/swag@latest

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Generate API documentation
RUN export PATH="/go/bin:${PATH}" && \
    cd /app && \
    go mod download && \
    go mod tidy && \
    swag init -g cmd/flowcontrol/main.go --parseDependency --parseInternal

# Build the application
RUN go build -o flow-control ./cmd/flowcontrol

# Development stage with hot reload
FROM golang:1.22.1-alpine AS dev

WORKDIR /app

RUN go install github.com/cosmtrek/air@latest
RUN go install github.com/swaggo/swag/cmd/swag@latest

COPY . .

CMD ["air"]

# Test stage
FROM golang:1.22.1-alpine AS test

WORKDIR /app

# Install build dependencies and tools
RUN apk add --no-cache gcc musl-dev sqlite-dev git curl && \
    go install github.com/swaggo/swag/cmd/swag@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Add Go binaries to PATH
ENV PATH="/go/bin:${PATH}"

COPY . .

CMD ["go", "test", "./..."]

# Production stage
FROM alpine:latest AS production

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache sqlite-dev

# Copy binary and documentation
COPY --from=builder /app/flow-control .
COPY --from=builder /app/docs ./docs
COPY web/ web/

RUN mkdir -p data logs

EXPOSE 8080

CMD ["./flow-control"] 