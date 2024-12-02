package types

import (
	"context"
)

// Package types defines the core interfaces and types for the Flow Control system.
// This package contains all shared type definitions to prevent circular dependencies
// and maintain a single source of truth for core types.
//
// Core types used from this package:
// - Port - Interface for message passing endpoints
// - Message - Data packet structure
// - Schema - Data validation interface
// - PortConfig - Port configuration structure
// - PortMetrics - Port performance metrics
// - PortStatus - Port operational status
// - QualityOfService - Message delivery guarantees

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

// QualityOfService defines the quality of service level for a port
type QualityOfService int

const (
	// QoSBestEffort provides no guarantees about message delivery
	QoSBestEffort QualityOfService = iota
	// QoSAtLeastOnce ensures messages are delivered at least once
	QoSAtLeastOnce
	// QoSExactlyOnce ensures messages are delivered exactly once
	QoSExactlyOnce
)

// String returns the string representation of QualityOfService
func (q QualityOfService) String() string {
	switch q {
	case QoSBestEffort:
		return "best-effort"
	case QoSAtLeastOnce:
		return "at-least-once"
	case QoSExactlyOnce:
		return "exactly-once"
	default:
		return "unknown"
	}
}
