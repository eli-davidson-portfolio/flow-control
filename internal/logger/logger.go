// Package logger implements structured logging for Flow Control.
package logger

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"flow-control/internal/types"

	"gopkg.in/natefinch/lumberjack.v2"
)

// Logger implements structured logging
type Logger struct {
	out io.Writer
}

// Config holds logger configuration
type Config struct {
	LogFile    string
	MaxSize    int
	MaxBackups int
	MaxAge     int
	Compress   bool
	Level      string
}

// New creates a new logger instance with the given configuration
func New(config Config) *Logger {
	// Create logs directory if it doesn't exist
	if err := os.MkdirAll(filepath.Dir(config.LogFile), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create logs directory: %v\n", err)
		os.Exit(1)
	}

	// Set up log rotation
	logFile := &lumberjack.Logger{
		Filename:   config.LogFile,
		MaxSize:    config.MaxSize,
		MaxBackups: config.MaxBackups,
		MaxAge:     config.MaxAge,
		Compress:   config.Compress,
	}

	// Write to both file and stdout
	return &Logger{
		out: io.MultiWriter(os.Stdout, logFile),
	}
}

// log writes a structured log entry
func (l *Logger) log(level string, msg string, err error, fields types.LogFields) {
	entry := map[string]interface{}{
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"level":     level,
		"message":   msg,
	}

	if err != nil {
		entry["error"] = err.Error()
	}

	if fields != nil {
		for k, v := range fields {
			entry[k] = v
		}
	}

	if err := json.NewEncoder(l.out).Encode(entry); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to encode log entry: %v\n", err)
	}
}

// Debug logs a debug message
func (l *Logger) Debug(msg string, fields types.LogFields) {
	l.log("debug", msg, nil, fields)
}

// Info logs an info message
func (l *Logger) Info(msg string, fields types.LogFields) {
	l.log("info", msg, nil, fields)
}

// Error logs an error message
func (l *Logger) Error(msg string, err error, fields types.LogFields) {
	l.log("error", msg, err, fields)
}

// Warn logs a warning message
func (l *Logger) Warn(msg string, fields types.LogFields) {
	l.log("warn", msg, nil, fields)
}
