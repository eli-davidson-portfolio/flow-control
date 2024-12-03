package types

import (
	"encoding/json"
	"time"
)

// RuntimeFlow represents a flow in the runtime
type RuntimeFlow struct {
	ID          string          `json:"id"`
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Version     string          `json:"version"`
	Config      json.RawMessage `json:"config"`
	Status      FlowStatus      `json:"status"`
	CreatedAt   time.Time       `json:"created_at"`
	UpdatedAt   time.Time       `json:"updated_at"`
}

// FlowStatus represents the current status of a flow
type FlowStatus string

const (
	// FlowStatusDraft indicates a flow that is not yet active
	FlowStatusDraft FlowStatus = "draft"
	// FlowStatusActive indicates a flow that is running
	FlowStatusActive FlowStatus = "active"
	// FlowStatusPaused indicates a flow that is temporarily stopped
	FlowStatusPaused FlowStatus = "paused"
	// FlowStatusError indicates a flow that has encountered an error
	FlowStatusError FlowStatus = "error"
	// FlowStatusCompleted indicates a flow that has finished execution
	FlowStatusCompleted FlowStatus = "completed"
)

// FlowEvent represents an event in the flow execution
type FlowEvent struct {
	ID        string          `json:"id"`
	FlowID    string          `json:"flow_id"`
	Type      string          `json:"type"`
	Data      json.RawMessage `json:"data"`
	CreatedAt time.Time       `json:"created_at"`
}

// FlowMetrics represents execution metrics for a flow
type FlowMetrics struct {
	FlowID           string    `json:"flow_id"`
	ExecutionCount   int64     `json:"execution_count"`
	LastExecutionAt  time.Time `json:"last_execution_at"`
	AverageLatencyMs float64   `json:"average_latency_ms"`
	ErrorCount       int64     `json:"error_count"`
	LastErrorAt      time.Time `json:"last_error_at"`
}
