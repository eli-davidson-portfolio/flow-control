# Flow Control Development Notes

## Project Structure

The project is organized into the following packages:

- `cmd/flow-control`: Main application entry point
- `internal/config`: Configuration management
- `internal/logger`: Structured logging
- `internal/parser`: Flow language parser
- `internal/server`: HTTP server and API
- `internal/store`: Persistent storage
- `internal/types`: Common types and interfaces

## Development Workflow

1. Code Organization
   - All packages are under `internal/` to prevent external usage
   - Common types are centralized in `types` package
   - Each package has its own tests in `_test` package
   - Documentation is generated automatically

2. Quality Control
   - All checks run in Docker for consistency
   - Pre-commit hook ensures code quality
   - Comprehensive test coverage
   - Package documentation and examples

3. Documentation
   - API documentation with Swagger
   - Package documentation with godoc
   - Code examples and tests
   - Development notes (this file)

## Docker Development Environment

1. Container Setup
   - Base image: golang:1.23-alpine
   - Development dependencies installed:
     - gcc
     - musl-dev
     - sqlite-dev
     - make
   - Development tools:
     - air (for hot reload)
     - swag (for API documentation)
     - golangci-lint (for linting)

2. Volume Management
   - Source code mounted at `/app`
   - Go cache mounted as volume for faster builds
   - SQLite database persisted in `data/` directory

3. Configuration
   - Environment variables:
     - GO_ENV=development/test
     - GOMODCACHE=/go/pkg/mod
     - GOCACHE=/go/cache
     - CONFIG_FILE=/app/config.json
   - Port mapping: 8080:8080
   - Hot reload enabled through air

4. Common Commands
   ```bash
   # Start development server
   docker compose up dev

   # Run tests
   docker compose run test

   # Run all checks (fmt, lint, test)
   make check

   # Stop all containers
   docker compose down
   ```

## Configuration System

1. File-based Configuration
   - JSON format
   - Default path: config.json
   - Can be overridden with CONFIG_FILE environment variable
   - Default values provided if no file exists

2. Configuration Structure
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

3. Validation Rules
   - Port must be between 1 and 65535
   - Database path must end with .db
   - Log level must be one of: trace, debug, info, warn, error
   - Log format must be one of: console, json

4. Directory Management
   - Database directory created automatically
   - Logs directory created as needed
   - All paths relative to workspace root

## Recent Updates

1. Docker Support
   - Added Docker and Docker Compose configuration
   - Created development environment with hot reload
   - Added test environment with development tools
   - Fixed networking issues
   - Containerized all development commands

2. Configuration Changes
   - Updated default host to 0.0.0.0
   - Added configuration file support
   - Improved validation
   - Fixed environment variable handling

3. Documentation
   - Updated README with Docker instructions
   - Added configuration documentation
   - Added API documentation
   - Updated development notes

## Next Steps

1. Testing
   - Add integration tests
   - Improve test coverage
   - Add benchmarks

2. Features
   - Flow validation
   - Node type plugins
   - Flow visualization

3. Documentation
   - Add user guide
   - Add developer guide
   - Add architecture documentation

## Package Documentation Requirements

1. Package Comments
   - Must be immediately before the package declaration with no blank lines
   - Must start with "Package [name]" and end with a period
   - Should be a single sentence describing the package's purpose
   - Example:
     ```go
     // Package logger implements structured logging for Flow Control.
     package logger
     ```

2. Documentation Style
   - Use line comments (`//`) for package documentation
   - Keep it simple and descriptive
   - Focus on what the package provides, not implementation details
   - Additional documentation can be added in doc.go files

3. Common Mistakes
   - Blank line between comment and package declaration
   - Missing period at end of comment
   - Not starting with "Package [name]"
   - Using block comments (`/* */`) for package documentation

## API Documentation Requirements

1. Swagger Annotations
   - Use `@Description` for detailed type descriptions
   - Use `@example` for field examples
   - Place annotations in the type's doc comment
   - Example:
     ```go
     // UserConfig represents a user configuration.
     // @Description A user configuration contains settings for a single user.
     type UserConfig struct {
         // Username of the user
         // @example "johndoe"
         Username string `json:"username"`
     }
     ```

2. Documentation Location
   - API types should be defined in a single location
   - Avoid duplicate type definitions with Swagger annotations
   - Use type aliases or imports to reference types
   - Example:
     ```go
     // Re-export types from central location
     type RuntimeFlow = types.RuntimeFlow
     type FlowEvent = types.FlowEvent
     ```

3. Common Mistakes
   - Duplicate type definitions with annotations
   - Missing or inconsistent annotations
   - Annotations in wrong location
   - Redundant type documentation

## Logging System

1. File-based Logging
   - Logs are written to `logs/flow-control.log` by default
   - JSON-formatted log entries for structured logging
   - Log rotation with configurable settings:
     - Maximum file size (default: 100MB)
     - Maximum number of backups (default: 5)
     - Maximum age of files (default: 30 days)
     - Compression of old files (enabled by default)

2. Log Levels
   - DEBUG: Detailed information for debugging
   - INFO: General operational information
   - WARN: Warning messages for potential issues
   - ERROR: Error conditions that need attention

3. Structured Fields
   - All log entries support structured fields
   - Component-based logging with `WithComponent`
   - Timestamp in UTC format
   - Error details included when relevant

4. Example Log Entry:
   ```json
   {
     "time": "2024-01-20T15:04:05Z",
     "level": "INFO",
     "message": "Server starting",
     "fields": {
       "component": "server",
       "port": 8080
     }
   }
   ```

5. Configuration
   - Configurable through `logger.Config`
   - Default configuration provided
   - Can be customized per instance
   - Log directory created automatically

## Log Analysis

1. Query Capabilities
   - Search by time range
   - Filter by log level
   - Filter by component
   - Search message content
   - Combine multiple criteria

2. Reading Methods
   - `ReadLogs`: Query logs with specific criteria
   - `ReadRecentLogs`: Get most recent N entries
   - `TailLogs`: Stream new log entries in real-time

3. Example Usage:
   ```go
   // Read logs from the last hour with errors
   logs, err := logger.ReadLogs(LogQuery{
       StartTime: time.Now().Add(-1 * time.Hour),
       Level:     "error",
   })

   // Get last 100 log entries
   recent, err := logger.ReadRecentLogs(100)

   // Stream logs in real-time
   stop := make(chan struct{})
   go logger.TailLogs(os.Stdout, stop)
   ```

4. Query Parameters
   - StartTime: Beginning of time range
   - EndTime: End of time range
   - Level: Log level filter (debug, info, warn, error)
   - Component: Filter by component name
   - Contains: Search text in message content

5. Use Cases
   - Debugging application issues
   - Monitoring system behavior
   - Auditing operations
   - Performance analysis
   - Error tracking and investigation