// Package types provides common types used throughout Flow Control.
// It defines interfaces and structs for flows, events, metrics, and logging.
package types

import "time"

// Schema represents a data type schema for Flow Control.
// It provides validation and type information for messages in the system.
type Schema interface {
	// Validate checks if the given data conforms to the schema
	Validate(data interface{}) error

	// GetType returns the schema type identifier
	GetType() string

	// GetVersion returns the schema version
	GetVersion() string
}

// Logger defines the interface for logging operations
type Logger interface {
	Debug(msg string, fields Fields)
	Info(msg string, fields Fields)
	Error(msg string, err error, fields Fields)
	Warn(msg string, fields Fields)
}

// Fields represents a set of key-value pairs for structured logging
type Fields map[string]interface{}

// RuntimeFlow represents a flow configuration and its runtime state
type RuntimeFlow struct {
	// ID uniquely identifies the flow
	ID string `json:"id"`

	// Name is a human-readable name for the flow
	Name string `json:"name"`

	// Description provides additional details about the flow
	Description string `json:"description,omitempty"`

	// Version is the flow's version number
	Version string `json:"version,omitempty"`

	// Config contains the flow's configuration in JSON format
	Config string `json:"config"`

	// Status represents the current state of the flow
	Status string `json:"status"`

	// CreatedAt is the timestamp when the flow was created
	CreatedAt time.Time `json:"created_at"`

	// UpdatedAt is the timestamp when the flow was last updated
	UpdatedAt time.Time `json:"updated_at"`
}

// FlowEvent represents a real-time event from a flow
type FlowEvent struct {
	// FlowID identifies the flow that generated the event
	FlowID string `json:"flow_id"`

	// NodeID identifies the node that generated the event
	NodeID string `json:"node_id"`

	// Type indicates the kind of event
	Type string `json:"type"`

	// Message provides details about the event
	Message string `json:"message"`

	// Data contains additional event-specific data
	Data map[string]interface{} `json:"data,omitempty"`

	// Timestamp indicates when the event occurred
	Timestamp time.Time `json:"timestamp"`
}

// FlowMetrics represents metrics collected during flow execution
type FlowMetrics struct {
	// FlowID identifies the flow being measured
	FlowID string `json:"flow_id"`

	// NodeID identifies the node being measured
	NodeID string `json:"node_id"`

	// StartTime is when the flow or node started executing
	StartTime time.Time `json:"start_time"`

	// EndTime is when the flow or node finished executing
	EndTime time.Time `json:"end_time"`

	// Duration is the total execution time in milliseconds
	Duration int64 `json:"duration"`

	// Status indicates the final execution status
	Status string `json:"status"`

	// Error contains any error message if execution failed
	Error string `json:"error,omitempty"`

	// Metrics contains additional metric data
	Metrics map[string]interface{} `json:"metrics,omitempty"`
}
