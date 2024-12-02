# Flow Control IDE

A real-time flow development IDE with a modern UI and powerful features.

## Features

- Custom flow language with syntax highlighting
- Real-time flow visualization using Mermaid diagrams
- Live metrics and logging
- SQLite database for flow storage
- Server-Sent Events (SSE) for real-time updates
- Modern UI with dark theme
- Hot reload during development
- Docker support for development and testing
- Webhook integration for automated deployments
- Comprehensive test framework for shell scripts

## Prerequisites

- Docker and Docker Compose
- Or locally:
  - Go 1.22 or later
  - SQLite3
  - Node.js (for Monaco Editor)
  - Bash 4+ (for testing framework)

## Getting Started

### Using Docker (Recommended)

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/flow-control.git
   cd flow-control
   ```

2. Start the development server:
   ```bash
   docker compose up dev
   ```

3. Run tests:
   ```bash
   # Run Go tests
   docker compose run test
   
   # Run shell script tests
   make test-scripts
   ```

4. Run code checks (formatting, linting, and tests):
   ```bash
   make check
   ```

### Staging Deployment

1. Clean the environment:
   ```bash
   # Standard cleanup
   make clean-env
   
   # Force cleanup (if needed)
   make clean-env-force
   ```

2. Deploy to staging:
   ```bash
   make setup-staging
   ```

3. Verify deployment:
   ```bash
   # Health check endpoints
   curl http://localhost:8080/health
   curl http://localhost:9000/hooks
   ```

### Webhook Integration

The application includes a webhook server for automated deployments:

1. Configuration (`config/hooks.json`):
   ```json
   {
     "id": "deploy",
     "execute-command": "/app/scripts/deploy.sh",
     "trigger-rule": {
       "match": {
         "type": "value",
         "value": "staging",
         "parameter": {
           "source": "payload",
           "name": "environment"
         }
       }
     }
   }
   ```

2. Trigger deployment:
   ```bash
   curl -X POST http://localhost:9000/hooks/deploy \
        -H "Content-Type: application/json" \
        -d '{"environment": "staging"}'
   ```

## Project Structure

```
/cmd
  /flowcontrol     # Entry point
/internal
  /server          # HTTP server, SSE, routing
  /flow            # Flow management
  /parser          # Custom syntax parser
  /store           # Database operations
  /metrics         # Metrics collection
  /logger          # Logging system
  /config          # Configuration management
/pkg               # Reusable packages
/web
  /templates       # HTML templates
  /static          # CSS, JS, etc.
/tests             # Integration tests
/scripts
  /lib             # Shell script libraries
    /docker        # Docker management
    /ports         # Port management
    /env           # Environment utilities
    /test          # Test framework
```

## Development

All development commands are containerized for consistency:

- Build the project: `make build`
- Run tests: `make test`
- Format code: `make fmt`
- Run linters: `make lint`
- Run all checks: `make check`
- Clean build files: `make clean`
- Generate docs: `make docs`
- Test shell scripts: `make test-scripts`

The pre-commit hook automatically runs all checks in Docker to ensure code quality.

## Configuration

The application can be configured using a JSON configuration file:

```json
{
  "server": {
    "host": "0.0.0.0",
    "port": 8080
  },
  "database": {
    "path": "data/flows.db"
  },
  "logging": {
    "level": "info",
    "format": "json",
    "file": "/app/logs/flow.log"
  }
}
```

Environment variables:
- `CONFIG_FILE`: Path to configuration file
- `LOG_LEVEL`: Logging level (error, warning, info, debug)
- `APP_PORT`: Application port (default: 8080)
- `WEBHOOK_PORT`: Webhook port (default: 9000)

## API Documentation

The API documentation is available through Swagger UI at http://localhost:8080/api/swagger/index.html when the server is running.

## Testing

1. Go Tests:
   ```bash
   make test
   ```

2. Shell Script Tests:
   ```bash
   make test-scripts
   ```

3. Integration Tests:
   ```bash
   make docker-test
   ```

4. Debug Mode:
   ```bash
   LOG_LEVEL=debug make <target>
   ```

## License

MIT License 