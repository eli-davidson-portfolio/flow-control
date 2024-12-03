package types

// LogFields represents structured logging fields
type LogFields map[string]interface{}

// Logger defines the interface for structured logging
type Logger interface {
	// Debug logs a debug message
	Debug(msg string, fields LogFields)

	// Info logs an info message
	Info(msg string, fields LogFields)

	// Warn logs a warning message
	Warn(msg string, fields LogFields)

	// Error logs an error message with error details
	Error(msg string, err error, fields LogFields)
} 