# Flow Control Project Notes

## Deployment Environments

### Development Environment
```bash
# Start development environment
make dev

Features:
- Hot reload enabled
- Test container included
- Automatic health checks
- Visual progress feedback
- Container status monitoring

Access URLs:
- App: http://localhost:8080
- API Docs: http://localhost:8080/swagger/index.html
- Health: http://localhost:8080/health

Useful Commands:
- View logs: make logs
- Run tests: make test
- Stop environment: make clean
```

### Staging Environment
```bash
# Deploy to staging
make staging

Features:
- Automated documentation generation
- Health verification
- Build progress monitoring
- Environment-aware host detection
- Container status monitoring

Access URLs:
- App: http://<staging-ip>:8080
- API Docs: http://<staging-ip>:8080/swagger/index.html
- Health: http://<staging-ip>:8080/health
- Webhook: http://<staging-ip>:9001/hooks/deploy

Deployment Steps:
1. Clean environment
2. Install dependencies
3. Generate API documentation
4. Build services
5. Start containers
6. Verify health endpoints
7. Display access information
```

## Build Process

### Documentation Generation
```bash
# Documentation is automatically generated during staging builds
# The process includes:
1. Installing swag tool
2. Parsing Go files for annotations
3. Generating Swagger/OpenAPI specs
4. Including internal packages
5. Processing dependencies

Output files:
- docs/docs.go
- docs/swagger.json
- docs/swagger.yaml
```

### Container Management
```bash
# Container Lifecycle
1. Build Phase
   - Install dependencies
   - Generate documentation
   - Compile application
   - Create Docker images

2. Startup Phase
   - Clean environment
   - Start containers
   - Wait for readiness
   - Verify health

3. Health Checks
   - Multiple retry attempts
   - Configurable timeouts
   - Status monitoring
   - Health endpoint verification
```

### Visual Feedback
```bash
# Progress Indicators
- Spinner for long operations
- Progress bars for builds
- Color-coded status messages
- Container health status
- Build summary display

# Status Symbols
⟳ Operation in progress
✓ Success
✗ Error
• Information
```

## Common Operations

### Testing
```bash
# Run all tests
make test

Features:
- Automatic test container
- Verbose output
- Failure logs
- Visual progress

# Format code
make fmt

# Run linters
make lint

# Run all checks
make check
```

### Logging
```bash
# View container logs
make logs

Features:
- Timestamped log files
- Container-specific logs
- Build logs
- Health check logs
- Error tracking
```

### Environment Management
```bash
# Clean environment
make clean

# Force cleanup
make clean-env-force

Features:
- Container cleanup
- Network cleanup
- Port management
- Resource cleanup
```

## Development Workflow

1. **Local Development**
   ```bash
   make dev
   # Make changes
   # Auto-reload active
   ```

2. **Testing Changes**
   ```bash
   make test
   make lint
   make check
   ```

3. **Staging Deployment**
   ```bash
   make staging
   # Verify deployment
   # Check health endpoints
   ```

## Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Ports needed:
   - 8080: Main application
   - 9001: Webhook (staging only)
   
   # Resolution:
   make clean-env-force
   ```

2. **Build Failures**
   ```bash
   # Check build logs:
   - Documentation generation issues
   - Dependency problems
   - Compilation errors
   
   # Resolution:
   make clean
   go mod tidy
   make staging
   ```

3. **Health Check Failures**
   ```bash
   # Common causes:
   - Container not ready
   - Port conflicts
   - Resource constraints
   
   # Resolution:
   make logs
   # Check specific container logs
   docker compose logs <container>
   ```

### Best Practices

1. **Development**
   - Use `make dev` for local development
   - Keep test container running
   - Monitor health endpoints
   - Use visual feedback

2. **Testing**
   - Run `make check` before commits
   - Monitor test container status
   - Check build progress
   - Verify documentation

3. **Deployment**
   - Clean environment first
   - Monitor build progress
   - Verify health checks
   - Check access URLs