// Package logger implements structured logging for Flow Control.
package logger

import (
	"log"

	"flow-control/internal/types"
)

// stdLogger implements the types.Logger interface using the standard log package
type stdLogger struct{}

// New creates a new logger instance that implements types.Logger
func New() types.Logger {
	return &stdLogger{}
}

// Debug logs a debug message with structured fields
func (l *stdLogger) Debug(msg string, fields types.Fields) {
	log.Printf("[DEBUG] %s %v", msg, fields)
}

// Info logs an info message with structured fields
func (l *stdLogger) Info(msg string, fields types.Fields) {
	log.Printf("[INFO] %s %v", msg, fields)
}

// Error logs an error message with error and structured fields
func (l *stdLogger) Error(msg string, err error, fields types.Fields) {
	log.Printf("[ERROR] %s: %v %v", msg, err, fields)
}

// Warn logs a warning message with structured fields
func (l *stdLogger) Warn(msg string, fields types.Fields) {
	log.Printf("[WARN] %s %v", msg, fields)
}

// WithComponent creates a logger with a component field
func WithComponent(component string) types.Fields {
	return types.Fields{"component": component}
}
