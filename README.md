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

## Prerequisites

- Docker and Docker Compose
- Or locally:
  - Go 1.22 or later
  - SQLite3
  - Node.js (for Monaco Editor)

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
   docker compose run test
   ```

4. Run code checks (formatting, linting, and tests):
   ```bash
   make check
   ```

### Local Development

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/flow-control.git
   cd flow-control
   ```

2. Initialize the development environment:
   ```bash
   make init
   ```

3. Start the development server with hot reload:
   ```bash
   make dev
   ```

   Or run without hot reload:
   ```bash
   make run
   ```

4. Open http://localhost:8080 in your browser

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
    "format": "console"
  }
}
```

The configuration file can be specified using the `CONFIG_FILE` environment variable:
```bash
CONFIG_FILE=config.json ./build/flowcontrol
```

## API Documentation

The API documentation is available through Swagger UI at http://localhost:8080/api/swagger/index.html when the server is running.

## License

MIT License 