# Flow Control

A modern flow-based programming system built with Go.

## Quick Start

### Development Environment

```bash
# Start development environment
make dev

# Run tests
make test

# Run linters
make lint

# Run all checks
make check
```

### Staging Environment

```bash
# Deploy to staging
make staging
```

## Features

- Hot reload for development
- Automatic health checks
- Visual progress feedback
- Container status monitoring
- Environment-aware host detection
- Automated documentation generation

## Development

### Prerequisites

- Docker
- Docker Compose
- Go 1.22 or later
- Make

### Environment Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/flow-control.git
   cd flow-control
   ```

2. Start development environment:
   ```bash
   make dev
   ```

3. Access the application:
   - App: http://localhost:8080
   - API Docs: http://localhost:8080/swagger/index.html
   - Health: http://localhost:8080/health

### Development Workflow

1. Make changes to the code
2. Tests run automatically
3. Application hot reloads
4. Run checks before committing:
   ```bash
   make check
   ```

### Testing

```bash
# Run all tests
make test

# Format code
make fmt

# Run linters
make lint

# Run all checks
make check
```

### Deployment

#### Development
```bash
make dev
```

#### Staging
```bash
make staging
```

### Container Management

```bash
# View logs
make logs

# Clean environment
make clean

# Force cleanup
make clean-env-force
```

## Documentation

- API documentation is automatically generated during build
- Swagger UI available at `/swagger/index.html`
- Health endpoint at `/health`

## Troubleshooting

### Common Issues

1. Port Conflicts
   ```bash
   # Resolution
   make clean-env-force
   ```

2. Build Failures
   ```bash
   # Resolution
   make clean
   go mod tidy
   make staging
   ```

3. Health Check Failures
   ```bash
   # Resolution
   make logs
   docker compose logs <container>
   ```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Run tests and linters
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.