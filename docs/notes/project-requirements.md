Create a real-time flow development IDE with the following specifications:

Core Architecture


Go backend with modular structure:
/cmd
  /flowcontrol
    main.go      # Entry point
/internal
  /server        # HTTP server, SSE, routing
  /flow          # Flow management, validation, visualization
  /parser        # Custom syntax parser
  /store         # Database operations
  /metrics       # Metrics collection
  /logger        # Logging system
  /config        # Configuration management
/pkg            # Reusable packages
/web
  /templates     # HTML templates (htmx)
  /static        # CSS, JS, etc.
/tests          # Integration tests

Use zerolog for structured logging
Use chi router for HTTP handling
Use SQLite with sqlc for type-safe queries
Server-Sent Events (SSE) for all real-time updates
Development mode with security bypassed
a demo UI has been provided to get started. remember to use htmx for frontend interactions, we are not using a full frontend framework, no react etc.


Database Schema
Create a SQLite schema with tables for:


flows (id, name, description, version, config, status, created_at, updated_at)
flow_versions (flow_id, version, code, metadata, created_at)
runtime_state (flow_id, status, error, started_at, updated_at, metrics, node_states)
metrics (flow_id, timestamp, metric_type, value, metadata)
logs (flow_id, timestamp, level, node_id, message, metadata)


Custom Flow Language
Design a custom syntax for flow definition:

flow "fileTransformationFlow" {
  config {
    // Flow-specific configurations
  }

  outputs {
    transformedData: {
      type: "text"
      from: {
        node: "transformer"
        port: "dataOut"
      }
    }
  }

  node "fileReader" {
    nodeType: "FileReader"

    config {
      path: "input.txt"
    }

    outputs {
      fileContent: {
        type: "text"
        to: [
          {
            node: "transformer"
            port: "dataIn"
          }
        ]
      }
    }
  }

  node "transformer" {
    nodeType: "Transform"

    config {
      operation: "uppercase"
    }

    inputs {
      dataIn: {
        type: "text"
        from: {
          node: "fileReader"
          port: "fileContent"
        }
      }
    }

    outputs {
      dataOut: {
        type: "text"
        // Connected to flow's output port
      }
    }
  }
}

Frontend Layout
Create a four-panel layout:

<div class="layout">
  <div class="sidebar">
    <!-- Flow list -->
  </div>
  <div class="main">
    <div class="top">
      <div class="diagram"><!-- Mermaid diagram --></div>
      <div class="metrics"><!-- Metrics panel --></div>
    </div>
    <div class="bottom">
      <div class="editor"><!-- Code panel --></div>
      <div class="logs"><!-- Log panel --></div>
    </div>
  </div>
</div>

Real-time Updates
Implement SSE endpoints:


/events/flows/{id}/status - Flow status updates
/events/flows/{id}/metrics - Metrics updates
/events/flows/{id}/logs - Log streaming
/events/flows/{id}/diagram - Diagram updates


Code Editor Features
Use Monaco Editor with:


Custom syntax highlighting for flow language
Auto-completion
Error highlighting
Format on save
Real-time validation


API Endpoints

GET    /api/flows           # List flows
POST   /api/flows           # Create flow
GET    /api/flows/:id       # Get flow
PUT    /api/flows/:id       # Update flow
DELETE /api/flows/:id       # Delete flow
POST   /api/flows/:id/start # Start flow
POST   /api/flows/:id/stop  # Stop flow

Flow Validation & Visualization


Parse flow code using custom parser
Validate node configurations and connections
Generate Mermaid diagram:

graph LR
  source[HTTP Input] --> transform[Transform]
  transform --> sink[Database]

Metrics & Logging


Collect metrics per node:
make scalable modular

recieved_messages
Processing time
Error rate
Custom metrics defined in node config


Log levels: debug, info, warn, error
Structured logging format
Log rotation
ability to turn off logging at node or flow level


Testing Requirements


Unit tests for all packages
Integration tests for API endpoints
Parser tests with various flow configurations
Metrics collection tests
SSE connection tests
Stress tests for concurrent updates


Error Handling


Custom error types for different failure modes
Error recovery strategies
User-friendly error messages
Validation error highlighting in editor


Build Pipeline


Makefile for common operations
Docker for development
Hot reload for development
Linting and formatting
pre-commit hooks
ci/cd pipeline github actions

Focus on:

Clean, maintainable code structure
Efficient real-time updates
Robust error handling
Comprehensive logging
Complete test coverage
Developer experience
Performance under load