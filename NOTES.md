# Flow Control Development Notes

## Core Concepts

1. Flow-Based Programming (FBP) Principles
   - Nodes are black boxes with well-defined interfaces
   - Connections are first-class entities
   - Information packets flow through connections
   - External configuration of nodes
   - Hierarchical network structure
   - Asynchronous processing

2. Node Lifecycle
   ```
   Creation → Configuration → Initialization → Processing → Shutdown
        ↑                                         |
        └─────────────── Reconfigure ────────────┘
   ```

3. Message Flow
   ```
   Source Node → Output Port → Connection → Input Port → Target Node
        ↑          |                                        |
        └──────────┴────────── Backpressure ───────────────┘
   ```

## Implementation Plan

1. Schema System (Phase 1 - Current)
   ```go
   internal/runtime/schema/
   ├── basic.go       # Basic type schemas (string, int, etc)
   ├── composite.go   # Struct and array schemas
   ├── validator.go   # Schema validation logic
   └── registry.go    # Schema type registry

   // Example usage:
   type JSONSchema struct {
       schemaType string
       version    string
       validator  *gojsonschema.Schema
   }

   func (s *JSONSchema) Validate(data interface{}) error {
       result, err := s.validator.Validate(gojsonschema.NewGoLoader(data))
       if err != nil {
           return err
       }
       if !result.Valid() {
           return fmt.Errorf("validation failed: %v", result.Errors())
       }
       return nil
   }
   ```

2. Port System (Phase 2)
   ```go
   internal/runtime/port/
   ├── base.go        # Base port implementation
   ├── buffer.go      # Message buffering
   ├── metrics.go     # Port metrics collection
   └── connection.go  # Port connections

   // Example usage:
   type BasePort struct {
       config    PortConfig
       buffer    *MessageBuffer
       metrics   *PortMetrics
       status    *PortStatus
       handlers  []MessageHandler
   }
   ```

3. Node System (Phase 3)
   ```go
   internal/runtime/node/
   ├── base.go        # BaseNode implementation
   ├── lifecycle.go   # Node lifecycle management
   ├── ports.go       # Port management
   └── registry.go    # Node type registry

   // Example usage:
   type BaseNode struct {
       config      NodeConfig
       metadata    NodeMetadata
       metrics     MetricsPort
       logs        LogPort
       traces      TracePort
       inputPorts  map[string]Port
       outputPorts map[string]Port
   }
   ```

4. Message System (Phase 4)
   ```go
   internal/runtime/message/
   ├── router.go      # Message routing
   ├── queue.go       # Message queuing
   ├── backpressure.go # Flow control
   └── delivery.go    # Message delivery guarantees

   // Example usage:
   type MessageRouter struct {
       routes    map[string][]string
       nodes     map[string]Node
       queue     *MessageQueue
       metrics   MetricsPort
   }
   ```

## Dependencies

1. Core Dependencies
   ```go
   require (
       // Metrics
       "github.com/prometheus/client_golang" v1.18.0
       
       // Tracing
       "go.opentelemetry.io/otel" v1.21.0
       
       // Logging
       "go.uber.org/zap" v1.26.0
       
       // Schema Validation
       "github.com/xeipuuv/gojsonschema" v1.2.0
       
       // Configuration
       "github.com/mitchellh/mapstructure" v1.5.0
   )
   ```

2. Development Tools
   ```bash
   # Install tools
   go install github.com/golangci-lint/golangci-lint@latest
   go install github.com/swaggo/swag/cmd/swag@latest
   go install github.com/cosmtrek/air@latest
   ```

## Testing Strategy

1. Unit Tests
   ```go
   // Schema testing
   func TestJSONSchema_Validate(t *testing.T) {
       schema := NewJSONSchema(`{
           "type": "object",
           "properties": {
               "name": {"type": "string"},
               "age": {"type": "integer"}
           }
       }`)
       
       // Test valid data
       err := schema.Validate(map[string]interface{}{
           "name": "John",
           "age": 30,
       })
       require.NoError(t, err)
       
       // Test invalid data
       err = schema.Validate(map[string]interface{}{
           "name": 123,
           "age": "invalid",
       })
       require.Error(t, err)
   }
   ```

2. Integration Tests
   ```go
   func TestNodeMessageFlow(t *testing.T) {
       // Create nodes
       source := NewTestNode("source")
       target := NewTestNode("target")
       
       // Connect nodes
       router := NewMessageRouter()
       router.RegisterNode(source)
       router.RegisterNode(target)
       
       // Send message
       msg := NewMessage("test", map[string]interface{}{
           "data": "hello",
       })
       
       err := source.Process(context.Background(), msg)
       require.NoError(t, err)
       
       // Verify message received
       received := target.LastMessage()
       require.Equal(t, msg.Payload, received.Payload)
   }
   ```

## Next Steps

1. Immediate Tasks
   - [ ] Implement basic Schema interface
   - [ ] Add JSON Schema validation
   - [ ] Create schema registry
   - [ ] Write schema tests

2. Port System Tasks
   - [ ] Design message buffer
   - [ ] Implement backpressure
   - [ ] Add metrics collection
   - [ ] Create connection manager

3. Node System Tasks
   - [ ] Create base node structure
   - [ ] Implement lifecycle methods
   - [ ] Add port management
   - [ ] Create node registry

4. Message System Tasks
   - [ ] Design routing system
   - [ ] Implement message queue
   - [ ] Add delivery guarantees
   - [ ] Create flow control

## Design Decisions

1. Schema System
   - Use JSON Schema for validation
   - Support custom validators
   - Include version control
   - Enable schema evolution

2. Port System
   - Ring buffer for messages
   - Configurable buffer size
   - Automatic backpressure
   - Metric collection

3. Node System
   - Pluggable architecture
   - Hot reload support
   - Resource management
   - State persistence

4. Message System
   - At-least-once delivery
   - Priority queuing
   - Dead letter queues
   - Message tracing

## Configuration

```json
{
  "runtime": {
    "schema_validation": true,
    "message_buffer_size": 1000,
    "max_concurrent_nodes": 100,
    "node_shutdown_timeout": "30s"
  },
  "telemetry": {
    "metrics_interval": "10s",
    "trace_sample_rate": 0.1,
    "log_format": "json"
  },
  "nodes": {
    "default_resources": {
      "cpu_limit": 1.0,
      "memory_limit": "256Mi",
      "max_concurrency": 10
    }
  }
}
```

# Development Process

## Code Organization

### Type Definitions
All type definitions should be in the `internal/types` package, organized by domain:
- `types.go` - Common types and interfaces
- `runtime.go` - Runtime and flow execution types
- `observability.go` - Metrics, logging, and tracing types
- `resources.go` - Resource management types

This centralization makes it easier to:
- Maintain type consistency
- Avoid circular dependencies
- Track type changes
- Prevent duplicate definitions

### Package Structure
- `internal/` - Internal packages
  - `types/` - All type definitions
  - `runtime/` - Runtime implementation
  - `server/` - HTTP server implementation
  - `store/` - Data storage implementation
  - etc.

## Development Workflow

1. **Local Development**
   - Run development server: `make dev`
   - Format code: `make fmt`
   - Run linters: `make lint`
   - Run tests: `make test`
   - Test specific package: `make test-pkg PKG=./path/to/package`

2. **Pre-commit Checks**
   The pre-commit hook automatically runs:
   - Code formatting
   - Linting
   - Tests
   Install hooks with: `make install-tools`

3. **CI/CD Pipeline**
   The CI pipeline runs in GitHub Actions and includes:
   - Code formatting check
   - Linting
   - Tests
   - Build verification
   All steps run in Docker for consistency with local development.

4. **Script Organization**
   - `scripts/common/` - Common environment and utilities
   - `scripts/build/` - Build and code quality tools
   - `scripts/test/` - Test runners and setup
   - `scripts/dev/` - Development server and tools
   - `scripts/tools/` - Tool installation and setup

5. **Docker Usage**
   - Development container: `golang:1.21.8-bullseye`
   - All commands run through Docker for consistency
   - Common dependencies managed in docker-env.sh
   - Persistent Go module cache through Docker volumes

6. **Code Quality**
   - Go formatting with `gofmt`
   - Linting with `golangci-lint`
   - Tests must pass in Docker environment
   - Pre-commit hooks ensure quality before commits

7. **Dependencies**
   - Managed through `go.mod`
   - Vendored dependencies for reproducible builds
   - Docker environment includes common system packages

8. **Documentation**
   - API docs generated with Swagger
   - Package documentation with godoc
   - Source code browser for exploration

# Type Organization

## Core Types

All type definitions are centralized in the `internal/types` package, organized by domain:

1. `runtime.go` - Package documentation and overview
2. `schema.go` - Data validation and type schemas
3. `node.go` - Flow processing nodes and configuration
4. `port.go` - Message ports and routing
5. `message.go` - Data packets and delivery
6. `resources.go` - Resource management and limits
7. `observability.go` - Metrics, logging, and tracing
8. `types.go` - Common interfaces and utilities

This organization:
- Keeps related types together
- Makes dependencies clear
- Prevents circular imports
- Makes changes easier to track
- Simplifies documentation

## Type Design Principles

1. **Single Responsibility**
   - Each type file focuses on one domain
   - Types are grouped by their role in the system
   - Clear separation of concerns

2. **Interface Segregation**
   - Interfaces are small and focused
   - Implementation details hidden
   - Easy to mock for testing

3. **Dependency Management**
   - Minimal dependencies between types
   - Clear dependency direction
   - No circular dependencies

4. **Documentation**
   - Each type file has package documentation
   - Interface methods documented
   - Examples provided where helpful

5. **Versioning**
   - Types support versioning where needed
   - Backward compatibility maintained
   - Migration paths documented

## Implementation Guidelines

1. **New Types**
   - Add to appropriate domain file
   - Follow existing patterns
   - Update package documentation

2. **Type Changes**
   - Consider backward compatibility
   - Update all implementations
   - Add migration notes if needed

3. **Testing**
   - Test interfaces thoroughly
   - Provide test helpers
   - Mock complex dependencies

4. **Documentation**
   - Keep docs up to date
   - Include examples
   - Note breaking changes