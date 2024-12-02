package types

import (
	"encoding/json"
	"time"
)

// Message represents a data message flowing through the system
type Message struct {
	ID       string          `json:"id"`
	Schema   Schema          `json:"schema"`
	Data     json.RawMessage `json:"data"`
	Metadata MessageMetadata `json:"metadata"`
}

// MessageMetadata contains metadata about a message
type MessageMetadata struct {
	Timestamp time.Time         `json:"timestamp"`
	Source    string           `json:"source"`
	Target    string           `json:"target"`
	Headers   map[string]string `json:"headers,omitempty"`
}
