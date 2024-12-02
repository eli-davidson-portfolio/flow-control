package types

import "time"

// Message represents a data packet in the flow
type Message struct {
	// Core data
	ID      string      `json:"id"`
	Payload interface{} `json:"payload"`
	Schema  Schema      `json:"schema"`
	
	// Routing
	SourceID string `json:"source_id"`
	TargetID string `json:"target_id"`
	FlowID   string `json:"flow_id"`
	
	// Metadata
	Timestamp time.Time         `json:"timestamp"`
	Headers   map[string]string `json:"headers"`
	
	// Observability
	TraceID string            `json:"trace_id"`
	SpanID  string            `json:"span_id"`
	Baggage map[string]string `json:"baggage"`
}

// QualityOfService defines message delivery guarantees
type QualityOfService struct {
	Reliability  ReliabilityLevel `json:"reliability"`
	Priority     int              `json:"priority"`
	TTL          time.Duration    `json:"ttl"`
	RetryPolicy  RetryPolicy      `json:"retry_policy"`
}

// ReliabilityLevel represents message delivery guarantees
type ReliabilityLevel string

const (
	ReliabilityAtMostOnce    ReliabilityLevel = "at_most_once"
	ReliabilityAtLeastOnce   ReliabilityLevel = "at_least_once"
	ReliabilityExactlyOnce   ReliabilityLevel = "exactly_once"
)

// RetryPolicy defines how to handle message delivery failures
type RetryPolicy struct {
	MaxAttempts  int           `json:"max_attempts"`
	InitialDelay time.Duration `json:"initial_delay"`
	MaxDelay     time.Duration `json:"max_delay"`
	Multiplier   float64       `json:"multiplier"`
} 