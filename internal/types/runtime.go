package types

// Package types provides core type definitions for Flow Control.
//
// The types are organized into several categories:
//
// Schema Types (schema.go):
//   - Schema interface for data validation
//
// Node Types (node.go):
//   - Node interface for processing units
//   - NodeConfig for configuration
//   - NodeMetadata for type information
//
// Port Types (port.go):
//   - Port interface for message passing
//   - PortConfig for configuration
//   - PortDirection for input/output
//
// Message Types (message.go):
//   - Message for data packets
//   - QualityOfService for delivery guarantees
//   - ReliabilityLevel for delivery modes
//   - RetryPolicy for failure handling
//
// Resource Types (resources.go):
//   - ResourceConfig for resource limits
//   - CPUConfig, MemoryConfig, etc.
//
// Observability Types (observability.go):
//   - MetricsPort for metrics collection
//   - LogPort for logging
//   - TracePort for tracing
