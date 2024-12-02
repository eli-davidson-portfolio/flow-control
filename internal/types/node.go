package types

import (
	"context"
)

// Node represents a processing unit in the flow
type Node interface {
	// Core functionality
	Process(ctx context.Context, input Message) (Message, error)
	
	// Configuration and metadata
	GetConfig() NodeConfig
	SetConfig(NodeConfig) error
	GetMetadata() NodeMetadata
	
	// Observability
	GetMetrics() MetricsPort
	GetLogs() LogPort
	GetTraces() TracePort
	
	// Lifecycle
	Init(ctx context.Context) error
	Start(ctx context.Context) error
	Stop(ctx context.Context) error
	Reset(ctx context.Context) error
}

// NodeConfig defines the configuration for a node
type NodeConfig struct {
	ID            string                 `json:"id"`
	Type          string                 `json:"type"`
	Version       string                 `json:"version"`
	InputPorts    []PortConfig          `json:"input_ports"`
	OutputPorts   []PortConfig          `json:"output_ports"`
	Settings      map[string]interface{} `json:"settings"`
	Resources     ResourceConfig         `json:"resources"`
	Observability ObservabilityConfig   `json:"observability"`
}

// NodeMetadata contains information about a node type
type NodeMetadata struct {
	Author      string             `json:"author"`
	License     string             `json:"license"`
	Repository  string             `json:"repository"`
	Tags        []string           `json:"tags"`
	Categories  []string           `json:"categories"`
	InputTypes  map[string]Schema  `json:"input_types"`
	OutputTypes map[string]Schema  `json:"output_types"`
} 