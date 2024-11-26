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
   - Linting with golangci-lint
   - Pre-commit hooks for formatting and linting
   - Comprehensive test coverage
   - Package documentation and examples

3. Documentation
   - API documentation with Swagger
   - Package documentation with godoc
   - Code examples and tests
   - Development notes (this file)

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

## Recent Updates

1. Documentation Generation
   - Added Swagger annotations
   - Created documentation server
   - Implemented automatic generation
   - Fixed documentation display issues

2. Code Organization
   - Centralized types in `types` package
   - Updated imports to use centralized types
   - Fixed import shadowing issues
   - Added comprehensive package documentation

3. Quality Control
   - Added golangci-lint configuration
   - Created pre-commit hooks
   - Fixed linting issues:
     - Package documentation
     - Test package organization
     - Error handling
     - Import shadowing
     - Code formatting

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