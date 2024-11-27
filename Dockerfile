# Build stage
FROM golang:1.22.9-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache gcc musl-dev sqlite-dev

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN go build -o flowcontrol ./cmd/flowcontrol

# Final stage
FROM alpine:latest

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache sqlite-dev

# Copy the binary from builder
COPY --from=builder /app/flowcontrol .

# Copy any necessary config files
COPY --from=builder /app/config ./config

EXPOSE 8080

CMD ["./flowcontrol"] 