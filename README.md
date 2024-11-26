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

## Prerequisites

- Go 1.21 or later
- SQLite3
- Node.js (for Monaco Editor)

## Getting Started

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

- Build the project: `make build`
- Run tests: `make test`
- Run tests with coverage: `make test-coverage`
- Run linter: `make lint`
- Clean build files: `make clean`

## Configuration

The application can be configured using a JSON configuration file:

```json
{
  "server": {
    "port": 8080,
    "host": "localhost"
  },
  "database": {
    "path": "flow-control.db"
  },
  "logger": {
    "level": "info",
    "format": "console"
  },
  "development": true
}
```

Pass the configuration file path using the `-config` flag:
```bash
./build/flowcontrol -config config.json
```

## License

MIT License 