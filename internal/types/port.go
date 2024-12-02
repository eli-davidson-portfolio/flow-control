package types

import (
	"context"
)

// Port represents a connection point for messages
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

// PortConfig defines the configuration for a port
type PortConfig struct {
	Name       string           `json:"name"`
	Type       string           `json:"type"`
	Direction  PortDirection    `json:"direction"`
	DataType   Schema           `json:"data_type"`
	BufferSize int              `json:"buffer_size"`
	QoS        QualityOfService `json:"qos"`
}

// PortDirection represents the direction of a port
type PortDirection string

const (
	// PortDirectionInput represents an input port that receives messages
	PortDirectionInput PortDirection = "input"
	// PortDirectionOutput represents an output port that sends messages
	PortDirectionOutput PortDirection = "output"
)
