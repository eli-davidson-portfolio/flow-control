package types

import "time"

// ResourceConfig defines resource limits and requirements for a node
type ResourceConfig struct {
	// Compute resources
	CPU     CPUConfig     `json:"cpu"`
	Memory  MemoryConfig  `json:"memory"`
	Storage StorageConfig `json:"storage"`

	// Time constraints
	Timeout     time.Duration `json:"timeout"`
	IdleTimeout time.Duration `json:"idle_timeout"`
	GracePeriod time.Duration `json:"grace_period"`

	// Concurrency
	MaxConcurrency int `json:"max_concurrency"`
	MaxBatchSize   int `json:"max_batch_size"`

	// Network
	Network NetworkConfig `json:"network"`
}

// CPUConfig defines CPU resource configuration
type CPUConfig struct {
	Limit    float64 `json:"limit"`    // CPU cores
	Request  float64 `json:"request"`  // CPU cores
	Priority int     `json:"priority"` // Scheduling priority
}

// MemoryConfig defines memory resource configuration
type MemoryConfig struct {
	Limit   int64 `json:"limit"`   // Bytes
	Request int64 `json:"request"` // Bytes
}

// StorageConfig defines storage resource configuration
type StorageConfig struct {
	Limit   int64  `json:"limit"`   // Bytes
	Request int64  `json:"request"` // Bytes
	Path    string `json:"path"`    // Storage path
}

// NetworkConfig defines network resource configuration
type NetworkConfig struct {
	IngressLimit int64    `json:"ingress_limit"` // Bytes per second
	EgressLimit  int64    `json:"egress_limit"`  // Bytes per second
	AllowedPorts []int    `json:"allowed_ports"`
	AllowedHosts []string `json:"allowed_hosts"`
}

// ResourceMetrics provides resource usage metrics
type ResourceMetrics struct {
	// CPU usage
	CPUUsage float64 // Percentage

	// Memory usage
	MemoryUsage   int64 // Bytes
	MemoryRSS     int64 // Resident Set Size
	MemoryHeap    int64 // Heap size
	MemoryGCPause time.Duration

	// Storage usage
	StorageUsage int64 // Bytes
	IORead       int64 // Bytes per second
	IOWrite      int64 // Bytes per second

	// Network usage
	NetworkIngress int64 // Bytes per second
	NetworkEgress  int64 // Bytes per second

	// Time metrics
	Uptime        time.Duration
	LastHeartbeat time.Time
}

// ResourceStatus represents the current state of node resources
type ResourceStatus struct {
	// State
	State     ResourceState
	LastError error

	// Usage
	Metrics ResourceMetrics

	// Limits
	CPULimit    float64
	MemoryLimit int64

	// Health
	Healthy     bool
	LastChecked time.Time
}

// ResourceState represents the state of node resources
type ResourceState string

const (
	// ResourceStateStarting indicates the resource is initializing
	ResourceStateStarting ResourceState = "starting"
	// ResourceStateRunning indicates the resource is operating normally
	ResourceStateRunning ResourceState = "running"
	// ResourceStateDegraded indicates the resource is operating with reduced capacity
	ResourceStateDegraded ResourceState = "degraded"
	// ResourceStateThrottled indicates the resource is being rate limited
	ResourceStateThrottled ResourceState = "throttled"
	// ResourceStateStopping indicates the resource is shutting down
	ResourceStateStopping ResourceState = "stopping"
	// ResourceStateStopped indicates the resource has stopped
	ResourceStateStopped ResourceState = "stopped"
)
