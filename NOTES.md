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

1. Schema System (Phase 1 - Completed)
   ```go
   // Core interface in internal/types/types.go
   type Schema interface {
       Validate(data interface{}) error
       GetType() string
       GetVersion() string
   }

   // Implementations in internal/runtime/schema/
   ├── basic.go       # Basic type schemas (string, int, etc) ✓
   ├── composite.go   # Struct and array schemas ✓
   ├── registry.go    # Schema type registry ✓
   └── schema_test.go # Schema test suite ✓

   // Implementation header comment
   // Package schema implements Schema interface from internal/types.
   // Core types used from internal/types:
   // - Schema (types.go) - Interface for data type validation
   // - Message (message.go) - Used in validation examples
   // - Fields (types.go) - Used for structured logging

   // Example implementation
   type BasicSchema struct {
       schemaType string
       version    string
       validator  func(interface{}) error
   }
   ```

2. Port System (Phase 2 - Current)
   ```go
   // Core interface in internal/types/port.go
   type Port interface {
       // Data flow
       Send(ctx context.Context, msg Message) error
       Receive(ctx context.Context) (Message, error)
       
       // Configuration
       GetConfig() PortConfig
       SetConfig(PortConfig) error
       
       // Flow control
       GetBackpressure() float64
       SetBufferSize(size int) error
       
       // Observability
       GetMetrics() PortMetrics
       GetStatus() PortStatus
   }

   // Implementations in internal/runtime/port/
   ├── base.go        # BasePort implementation with core logic
   ├── buffer.go      # Ring buffer for message queuing
   ├── metrics.go     # Port metrics collection
   └── connection.go  # Port-to-port connections

   // Implementation header comment
   // Package port implements Port interface from internal/types.
   // Core types used from internal/types:
   // - Port (port.go) - Interface for message passing
   // - Message (message.go) - Data packets
   // - PortConfig (port.go) - Port configuration
   // - PortMetrics (observability.go) - Metrics collection

   // Example implementation
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
   // Core interface in internal/types/node.go
   type Node interface {
       Process(ctx context.Context, input Message) (Message, error)
       GetConfig() NodeConfig
       SetConfig(NodeConfig) error
       GetMetadata() NodeMetadata
   }

   // Implementations in internal/runtime/node/
   ├── base.go        # BaseNode implementation
   ├── lifecycle.go   # Node lifecycle management
   ├── ports.go       # Port management
   └── registry.go    # Node type registry

   // Implementation header comment
   // Package node implements Node interface from internal/types.
   // Core types used from internal/types:
   // - Node (node.go)
   // - Message (message.go)
   // - NodeConfig (node.go)

   // Example implementation
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
   // Core types in internal/types/message.go
   type Message struct {
       ID      string
       Payload interface{}
       Schema  Schema
       Headers map[string]string
   }

   // Implementations in internal/runtime/message/
   ├── router.go      # Message routing
   ├── queue.go       # Message queuing
   ├── backpressure.go # Flow control
   └── delivery.go    # Message delivery guarantees

   // Implementation header comment
   // Package message implements message handling for Flow Control.
   // Core types used from internal/types:
   // - Message (message.go)
   // - Schema (types.go)
   // - Node (node.go)

   // Example implementation
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
       // HTTP Server
       "github.com/go-chi/chi/v5" v5.1.0
       
       // Database
       "github.com/mattn/go-sqlite3" v1.14.24
       
       // Testing
       "github.com/stretchr/testify" v1.8.4
       
       // API Documentation
       "github.com/swaggo/http-swagger" v1.3.4
       "github.com/swaggo/swag" v1.16.4
       
       // Logging
       "gopkg.in/natefinch/lumberjack.v2" v2.2.1
   )
   ```

2. Development Tools
   ```bash
   # Install tools (scripts/tools/install.sh)
   go install github.com/golangci/lint/golangci-lint@latest
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
   - [x] Implement basic Schema interface
   - [x] Add JSON Schema validation
   - [x] Create schema registry
   - [x] Write schema tests
   - [ ] Begin Port System implementation

2. Port System Tasks
   - [ ] Design and implement MessageBuffer with ring buffer
   - [ ] Create BasePort with core Send/Receive logic
   - [ ] Add backpressure monitoring and control
   - [ ] Implement port metrics collection
   - [ ] Add port status tracking
   - [ ] Create connection management system
   - [ ] Write comprehensive port tests
   - [ ] Add port configuration validation
   - [ ] Implement graceful shutdown handling
   - [ ] Add message filtering capabilities

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
   - Basic type validation with custom validators ✓
   - Composite types (arrays, objects) support ✓
   - Version control with compatibility checks ✓
   - Centralized type definitions in types.go ✓
   - Registry for type management ✓
   - Extensible validation system ✓
   - Thread-safe implementation ✓

2. Port System
   - Ring buffer implementation for efficient message queuing
   - Configurable buffer sizes with automatic resizing
   - Backpressure monitoring and flow control
   - Real-time metrics collection
   - Connection lifecycle management
   - Support for different message delivery modes
   - Thread-safe implementation
   - Graceful shutdown handling
   - Message filtering and transformation
   - Error handling and recovery

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
   ```bash
   # Development Commands
   make dev              # Run development server
   make fmt              # Format code
   make lint             # Run linters
   make test             # Run tests
   make test-pkg PKG=./path/to/package  # Test specific package
   
   # Development Flow
   1. Edit code
   2. Tests run automatically on save
   3. Linting runs automatically
   4. Local development server reloads
   ```

2. **Automated Environment Management**
   ```bash
   # Docker Environment
   ./scripts/docker-check.sh  # Verify/fix Docker environment
   Options:
   --quiet         # Suppress non-essential output
   --no-compose    # Skip Docker Compose checks
   
   Features:
   - Automatic Docker Desktop startup
   - Version compatibility checks
   - Image/container management
   - Resource monitoring
   - Cache management
   ```

3. **Test Management**
   ```bash
   # Test Commands
   ./scripts/test.sh    # Run all tests
   Options:
   --package PKG      # Test specific package
   --local           # Run tests locally
   --retry N         # Retry flaky tests
   --format FMT      # Output format
   
   Features:
   - Test caching
   - Parallel execution
   - Flaky test handling
   - Dependency management
   ```

4. **Pre-commit System**
   ```bash
   # Configuration (.flowcontrol/config.yml)
   checks:
     format: true
     lint: true
     test: true
     docker: true
   
   # Features
   - Configurable checks
   - Parallel execution
   - Incremental checking
   - Cache management
   ```

5. **CI/CD Pipeline**
   ```bash
   # GitHub Actions Workflow
   ├── Environment Check
   │   ├── Docker verification
   │   └── Resource validation
   │
   ├── Code Quality
   │   ├── Formatting
   │   ├── Linting
   │   └── Static analysis
   │
   ├── Testing
   │   ├── Unit tests
   │   ├── Integration tests
   │   └── Coverage report
   │
   └── Build
       ├── Binary compilation
       ├── Docker image
       └── Documentation
   ```

6. **Script Organization**
   ```bash
   scripts/
   ├── common/           # Shared utilities
   │   ├── docker-env.sh    # Docker environment
   │   └── docker-check.sh  # Environment verification
   │
   ├── build/           # Build tools
   │   ├── format.sh       # Code formatting
   │   └── lint.sh         # Code linting
   │
   ├── test/            # Test runners
   │   ├── setup.sh        # Test environment
   │   └── run.sh          # Test execution
   │
   ├── dev/             # Development tools
   │   └── server.sh       # Dev server
   │
   └── tools/           # Tool management
       └── install.sh      # Tool installation
   ```

7. **Error Recovery**
   ```bash
   # Common Issues
   - Docker not running
   - Missing dependencies
   - Resource exhaustion
   - Network conflicts
   
   # Recovery Flow
   1. Automatic detection
   2. Environment verification
   3. Automatic recovery
   4. Clear error reporting
   5. User guidance
   ```

8. **Development States**
   ```bash
   # State Management
   ├── Environment
   │   ├── Docker status
   │   ├── Dependencies
   │   └── Resources
   │
   ├── Code Quality
   │   ├── Format state
   │   ├── Lint state
   │   └── Test state
   │
   └── Development
       ├── Server status
       ├── Hot reload
       └── Debug state
   ```

This workflow is designed to:
- Minimize development friction
- Automate common tasks
- Handle edge cases gracefully
- Provide clear feedback
- Maintain code quality

# Type Organization

## Core Types

All type definitions are centralized in the `internal/types` package, organized by domain:

1. `types.go` - Common interfaces and utilities
   - Schema interface
   - Logger interface
   - Fields type
   - Flow types
2. `schema.go` - Data validation and type schemas (moved to types.go)
3. `node.go` - Flow processing nodes and configuration
4. `port.go` - Message ports and routing
5. `message.go` - Data packets and delivery
6. `resources.go` - Resource management and limits
7. `observability.go` - Metrics, logging, and tracing
8. `runtime.go` - Runtime and execution types

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

6. **Type Definition Prevention**
   - All core types defined in `internal/types` package
   - Each file must have a header comment listing imported types
   - Example header:
     ```go
     // Package schema implements Schema interface from internal/types.
     // Core types used from internal/types:
     // - Schema (types.go)
     // - Message (message.go)
     // - NodeConfig (node.go)
     ```
   - This prevents accidental type redefinition
   - Makes dependencies explicit
   - Helps with code review

## Implementation Guidelines

1. **New Types**
   - Add to appropriate domain file
   - Follow existing patterns
   - Update package documentation
   - Add header comment listing imported types

2. **Type Changes**
   - Consider backward compatibility
   - Update all implementations
   - Add migration notes if needed
   - Update header comments in affected files

3. **Testing**
   - Test interfaces thoroughly
   - Provide test helpers
   - Mock complex dependencies

4. **Documentation**
   - Keep docs up to date
   - Include examples
   - Note breaking changes

## Docker Environment Management

1. **Automatic Recovery**
   ```bash
   # Docker environment checks (scripts/common/docker-check.sh)
   ├── System Requirements
   │   ├── Disk space verification (10GB minimum)
   │   ├── User permissions (docker group)
   │   └── OS compatibility checks
   │
   ├── Installation Recovery
   │   ├── Docker Desktop (macOS)
   │   ├── Docker Engine (Linux)
   │   └── Docker Compose
   │
   ├── Runtime Recovery
   │   ├── Daemon status check
   │   ├── Service startup
   │   └── API compatibility
   │
   └── Resource Management
       ├── Disk usage monitoring
       ├── Automatic cleanup
       └── Container health checks
   ```

2. **Recovery Scenarios**
   ```bash
   # Installation Issues
   - Missing Docker installation
   - Missing Docker Compose
   - Incomplete/corrupted installation
   - Missing system dependencies
   
   # Permission Issues
   - Non-root user without docker group
   - Missing systemd permissions
   - Socket permission issues
   
   # Runtime Issues
   - Stopped Docker daemon
   - Crashed Docker service
   - Resource exhaustion
   - Disk space issues
   
   # Resource Issues
   - Full disk space
   - Too many containers
   - Network conflicts
   - Memory pressure
   ```

3. **Recovery Strategy**
   ```bash
   # Recovery Flow
   Installation → Permissions → Runtime → Resources
   
   # Each step includes:
   - Verification of current state
   - Automatic recovery attempt
   - Multiple retry attempts
   - Clear error reporting
   - User guidance for manual steps
   ```

4. **Monitoring and Maintenance**
   ```bash
   # Automatic Checks
   - Pre-command verification
   - Resource monitoring
   - Health checks
   - Cleanup triggers
   
   # Maintenance Tasks
   - Unused resource cleanup
   - Image pruning
   - Volume management
   - Network cleanup
   ```

5. **Error Handling**
   ```bash
   # Error Levels
   - Recoverable (retry with backoff)
   - User-fixable (show instructions)
   - System-level (require admin)
   - Fatal (stop execution)
   
   # Recovery Actions
   - Automatic retry (3 attempts)
   - Resource cleanup
   - Service restart
   - User notification
   ```

## Deployment Strategy

1. Environment Setup
   ```bash
   # Environment types
   - Development (local): Uses docker-compose.yml
   - Staging: Uses docker-compose.yml + docker-compose.staging.yml
   - Production (future): Will use docker-compose.yml + docker-compose.prod.yml
   ```

2. Staging Environment
   ```bash
   # Components
   - Docker Compose for container orchestration
   - Webhook for automated deployments (port 9000)
   - Deploy user with restricted permissions
   - SSH deploy keys for secure repository access
   - Memory-optimized for 1GB servers (512MB min, 1GB max)
   
   # Directory Structure
   /opt/flow-control/
   ├── .env.staging      # Environment variables
   ├── .ssh/            # Deploy keys
   │   ├── id_ed25519   # Private key
   │   └── config       # SSH configuration
   ├── config/          # Configuration files
   │   └── hooks.json   # Webhook configuration
   ├── logs/            # Application logs
   │   └── deploy.log   # Deployment logs
   ├── data/            # Persistent data
   │   └── backups/     # Database backups
   └── scripts/         # Deployment scripts
       ├── common/      # Shared scripts
       ├── setup/       # Environment setup
       └── staging/     # Staging-specific scripts
   ```

3. Initial Setup Process
   ```bash
   # On Local Machine
   1. Clone repository
   2. Create staging branch
   3. Push to GitHub
   
   # On Staging Server
   1. Run setup:
      make setup-staging
   
   2. Add deploy key to GitHub:
      - Go to repo Settings → Deploy Keys
      - Add key from setup output
      - Enable write access if needed
   
   3. Start application:
      make staging
   ```

4. Deployment Process
   ```bash
   # Manual Deployment
   make staging       # Starts application in staging mode
   
   # Automated Deployment (via webhook)
   1. Push to staging branch
   2. Webhook triggers deploy.sh
   3. Database backup created
   4. Code updated via git pull
   5. Application restarted with make staging
   6. Health check verification
   7. Automatic rollback on failure
   ```

5. Security Considerations
   ```bash
   # Access Control
   - Deploy user with minimal permissions
   - SSH keys with read-only access (default)
   - Firewall rules:
     * SSH (22)
     * HTTP (80)
     * Application (8080)
     * Webhook (9000)
   
   # Environment Isolation
   - Separate Docker network (flow-network)
   - Environment-specific configs
   - Memory limits enforced
   - Automatic container restarts
   ```

6. Maintenance
   ```bash
   # Logs
   - Application logs in /opt/flow-control/logs/
   - Deployment logs in /opt/flow-control/logs/deploy.log
   
   # Backups
   - Auto-backup before each deployment
   - Kept in /opt/flow-control/data/backups/
   - Last 7 backups retained
   
   # Monitoring
   - Health check endpoint: /health
   - Memory usage monitoring
   - Container status checks
   ```