# Build stage
FROM golang:1.22.1-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache gcc musl-dev sqlite-dev

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN go build -o flow-control ./cmd/flowcontrol

# Development stage with hot reload
FROM golang:1.22.1-alpine AS dev

WORKDIR /app

RUN go install github.com/cosmtrek/air@latest

COPY . .

CMD ["air"]

# Production stage
FROM alpine:latest AS production

WORKDIR /app

COPY --from=builder /app/flow-control .

COPY web/ web/

COPY .env.staging .env

RUN mkdir -p data logs

EXPOSE 8080

CMD ["./flow-control"]

# Test stage
FROM golang:1.22.1-alpine AS test

WORKDIR /app

COPY . .

CMD ["go", "test", "./..."] 