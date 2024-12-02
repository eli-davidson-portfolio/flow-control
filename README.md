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

# Docker Configuration

## Network Configuration

When using host networking mode (`network_mode: host`), there are important considerations for service binding:

1. **Service Ports**
   - Bind services to `0.0.0.0` to accept external connections
   - Configure in `docker-compose.yml`:
     ```yaml
     services:
       app:
         environment:
           SERVER_HOST: "0.0.0.0"  # Allow external access
     ```

2. **Health Checks**
   - Use `127.0.0.1` for internal health checks
   - Example configuration:
     ```yaml
     services:
       app:
         healthcheck:
           test: ["CMD", "curl", "-f", "http://127.0.0.1:8080/health"]
     ```

3. **Common Issues**
   - Binding to `127.0.0.1` prevents external access
   - Container health checks may pass while external access fails
   - Solution: Always bind services to `0.0.0.0` with host networking

4. **Port Management**
   - Health checks use localhost (`127.0.0.1`)
   - Services bind to all interfaces (`0.0.0.0`)
   - Port conflicts are automatically resolved
   - Ports are released gracefully on shutdown