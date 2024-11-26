// Package types defines the core types used throughout Flow Control.
//
// The types package contains the fundamental data structures and interfaces that
// are shared across different packages in the Flow Control system. This includes
// flow definitions, events, metrics, and logging interfaces.
//
// Key types:
//
// - Flow: Represents a flow configuration and its runtime state
// - FlowEvent: Represents events emitted during flow execution
// - FlowMetrics: Contains metrics collected during flow execution
// - Logger: Interface for structured logging
//
// Example Flow structure:
//
//	type Flow struct {
//	    ID          string    `json:"id"`
//	    Name        string    `json:"name"`
//	    Description string    `json:"description,omitempty"`
//	    Version     string    `json:"version,omitempty"`
//	    Config      string    `json:"config"`
//	    Status      string    `json:"status"`
//	    CreatedAt   time.Time `json:"created_at"`
//	    UpdatedAt   time.Time `json:"updated_at"`
//	}
//
// The types in this package are designed to be:
//
// - Serializable: All types can be marshaled to/from JSON
// - Documented: Types include Swagger annotations for API documentation
// - Extensible: Types can be extended without breaking compatibility
package types
