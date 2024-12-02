package types

import (
	"context"
	"time"
)

// MetricsPort provides metrics collection capabilities
type MetricsPort interface {
	// Counter operations
	Inc(name string, value float64, labels map[string]string)
	Dec(name string, value float64, labels map[string]string)

	// Gauge operations
	Set(name string, value float64, labels map[string]string)

	// Histogram operations
	Observe(name string, value float64, labels map[string]string)

	// Management
	Register(collector MetricsCollector) error
	Unregister(collector MetricsCollector) error
}

// MetricsCollector represents a metrics collector implementation
type MetricsCollector interface {
	Collect() ([]Metric, error)
	Describe() []MetricDesc
}

// Metric represents a single metric point
type Metric struct {
	Name   string
	Type   MetricType
	Value  float64
	Labels map[string]string
	Time   time.Time
}

// MetricDesc describes a metric
type MetricDesc struct {
	Name        string
	Type        MetricType
	Description string
	Labels      []string
}

// MetricType represents the type of a metric
type MetricType string

const (
	// MetricTypeCounter represents a cumulative metric that can only increase
	MetricTypeCounter MetricType = "counter"
	// MetricTypeGauge represents a metric that can increase and decrease
	MetricTypeGauge MetricType = "gauge"
	// MetricTypeHistogram represents a metric that samples observations
	MetricTypeHistogram MetricType = "histogram"
)

// LogPort provides structured logging capabilities
type LogPort interface {
	// Log levels
	Debug(msg string, fields Fields)
	Info(msg string, fields Fields)
	Warn(msg string, fields Fields)
	Error(msg string, err error, fields Fields)

	// Configuration
	SetLevel(level LogLevel)
	AddHook(hook LogHook)

	// Context
	WithContext(ctx context.Context) LogPort
	WithFields(fields Fields) LogPort
}

// LogLevel represents logging levels
type LogLevel string

const (
	// LogLevelDebug represents detailed information for debugging
	LogLevelDebug LogLevel = "debug"
	// LogLevelInfo represents general operational information
	LogLevelInfo LogLevel = "info"
	// LogLevelWarn represents potentially harmful situations
	LogLevelWarn LogLevel = "warn"
	// LogLevelError represents error events that might still allow the application to continue running
	LogLevelError LogLevel = "error"
)

// LogHook allows extending logging functionality
type LogHook interface {
	Levels() []LogLevel
	Fire(entry LogEntry) error
}

// LogEntry represents a log entry
type LogEntry struct {
	Level   LogLevel
	Message string
	Fields  Fields
	Time    time.Time
	Error   error
	TraceID string
	SpanID  string
}

// TracePort provides distributed tracing capabilities
type TracePort interface {
	// Span operations
	StartSpan(name string, opts ...SpanOption) (Span, context.Context)
	InjectSpan(ctx context.Context, carrier interface{}) error
	ExtractSpan(ctx context.Context, carrier interface{}) (context.Context, error)

	// Baggage
	GetBaggage(ctx context.Context) map[string]string
	SetBaggage(ctx context.Context, key, value string) context.Context
}

// Span represents a tracing span
type Span interface {
	// Context and metadata
	Context() context.Context
	SetName(name string)
	SetAttributes(attrs map[string]interface{})

	// Events and errors
	AddEvent(name string, attrs map[string]interface{})
	RecordError(err error)

	// Lifecycle
	End()
	IsRecording() bool
}

// SpanOption configures a span
type SpanOption interface {
	Apply(*SpanConfig)
}

// SpanConfig contains span configuration
type SpanConfig struct {
	Parent     context.Context
	Attributes map[string]interface{}
	StartTime  time.Time
}

// ObservabilityConfig configures node observability
type ObservabilityConfig struct {
	// Metrics configuration
	MetricsEnabled bool              `json:"metrics_enabled"`
	MetricsTags    map[string]string `json:"metrics_tags"`

	// Logging configuration
	LogLevel  LogLevel          `json:"log_level"`
	LogFormat string            `json:"log_format"`
	LogFields map[string]string `json:"log_fields"`

	// Tracing configuration
	TracingEnabled bool              `json:"tracing_enabled"`
	TraceTags      map[string]string `json:"trace_tags"`
}

// PortMetrics provides port-specific metrics
type PortMetrics struct {
	MessagesIn   int64
	MessagesOut  int64
	BytesIn      int64
	BytesOut     int64
	LastMessage  time.Time
	ErrorCount   int64
	Backpressure float64
}

// PortStatus represents the current state of a port
type PortStatus struct {
	Connected    bool
	BufferSize   int
	BufferUsage  float64
	LastError    error
	LastActivity time.Time
}
