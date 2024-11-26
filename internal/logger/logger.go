// Package logger implements structured logging for Flow Control.
package logger

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"flow-control/internal/types"

	"gopkg.in/natefinch/lumberjack.v2"
)

// Config holds logger configuration
type Config struct {
	// LogFile is the path to the log file
	LogFile string
	// MaxSize is the maximum size in megabytes of the log file before it gets rotated
	MaxSize int
	// MaxBackups is the maximum number of old log files to retain
	MaxBackups int
	// MaxAge is the maximum number of days to retain old log files
	MaxAge int
	// Compress determines if the rotated log files should be compressed
	Compress bool
	// Level is the minimum logging level
	Level string
}

// DefaultConfig returns the default logger configuration
func DefaultConfig() Config {
	return Config{
		LogFile:    "logs/flow-control.log",
		MaxSize:    100,    // 100MB
		MaxBackups: 5,      // Keep 5 old files
		MaxAge:     30,     // 30 days
		Compress:   true,   // Compress old files
		Level:      "info", // Default to info level
	}
}

// LogEntry represents a single log entry
type LogEntry struct {
	Time    string                 `json:"time"`
	Level   string                 `json:"level"`
	Message string                 `json:"message"`
	Error   string                 `json:"error,omitempty"`
	Fields  map[string]interface{} `json:"fields,omitempty"`
}

// LogQuery represents search criteria for log entries
type LogQuery struct {
	StartTime time.Time
	EndTime   time.Time
	Level     string
	Component string
	Contains  string
}

// Logger implements structured logging with file output
type Logger struct {
	config Config
	writer *lumberjack.Logger
}

// New creates a new logger instance with the given configuration
func New(config ...Config) types.Logger {
	cfg := DefaultConfig()
	if len(config) > 0 {
		cfg = config[0]
	}

	// Ensure log directory exists
	if err := os.MkdirAll(filepath.Dir(cfg.LogFile), 0o755); err != nil {
		fmt.Printf("Failed to create log directory: %v\n", err)
	}

	l := &Logger{
		config: cfg,
		writer: &lumberjack.Logger{
			Filename:   cfg.LogFile,
			MaxSize:    cfg.MaxSize,
			MaxBackups: cfg.MaxBackups,
			MaxAge:     cfg.MaxAge,
			Compress:   cfg.Compress,
		},
	}

	return l
}

// log writes a log entry to the file
func (l *Logger) log(level, msg string, err error, fields types.Fields) {
	entry := struct {
		Time    string                 `json:"time"`
		Level   string                 `json:"level"`
		Message string                 `json:"message"`
		Error   string                 `json:"error,omitempty"`
		Fields  map[string]interface{} `json:"fields,omitempty"`
	}{
		Time:    time.Now().UTC().Format(time.RFC3339),
		Level:   level,
		Message: msg,
		Fields:  fields,
	}

	if err != nil {
		entry.Error = err.Error()
	}

	data, err := json.Marshal(entry)
	if err != nil {
		fmt.Printf("Failed to marshal log entry: %v\n", err)
		return
	}

	if _, err := l.writer.Write(append(data, '\n')); err != nil {
		fmt.Printf("Failed to write log entry: %v\n", err)
	}
}

// Debug logs a debug message with structured fields
func (l *Logger) Debug(msg string, fields types.Fields) {
	if l.config.Level == "debug" {
		l.log("DEBUG", msg, nil, fields)
	}
}

// Info logs an info message with structured fields
func (l *Logger) Info(msg string, fields types.Fields) {
	if l.config.Level != "error" {
		l.log("INFO", msg, nil, fields)
	}
}

// Error logs an error message with error and structured fields
func (l *Logger) Error(msg string, err error, fields types.Fields) {
	l.log("ERROR", msg, err, fields)
}

// Warn logs a warning message with structured fields
func (l *Logger) Warn(msg string, fields types.Fields) {
	if l.config.Level != "error" {
		l.log("WARN", msg, nil, fields)
	}
}

// WithComponent creates a logger with a component field
func WithComponent(component string) types.Fields {
	return types.Fields{"component": component}
}

// ReadLogs reads log entries matching the given query
func (l *Logger) ReadLogs(query *LogQuery) ([]LogEntry, error) {
	file, err := os.Open(l.config.LogFile)
	if err != nil {
		return nil, fmt.Errorf("failed to open log file: %w", err)
	}
	defer func() {
		if err := file.Close(); err != nil {
			l.Error("Failed to close log file", err, nil)
		}
	}()

	var entries []LogEntry
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		var entry LogEntry
		if err := json.Unmarshal(scanner.Bytes(), &entry); err != nil {
			continue // Skip invalid entries
		}

		if matchesQuery(entry, query) {
			entries = append(entries, entry)
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading log file: %w", err)
	}

	return entries, nil
}

// ReadRecentLogs reads the most recent n log entries
func (l *Logger) ReadRecentLogs(n int) ([]LogEntry, error) {
	file, err := os.Open(l.config.LogFile)
	if err != nil {
		return nil, fmt.Errorf("failed to open log file: %w", err)
	}
	defer func() {
		if err := file.Close(); err != nil {
			l.Error("Failed to close log file", err, nil)
		}
	}()

	// Read file from end using a ring buffer
	ring := make([]string, n)
	pos := 0
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		ring[pos] = scanner.Text()
		pos = (pos + 1) % n
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading log file: %w", err)
	}

	// Reconstruct entries in chronological order
	var entries []LogEntry
	for i := 0; i < n; i++ {
		idx := (pos + i) % n
		if ring[idx] == "" {
			continue
		}
		var entry LogEntry
		if err := json.Unmarshal([]byte(ring[idx]), &entry); err != nil {
			continue
		}
		entries = append(entries, entry)
	}

	return entries, nil
}

// TailLogs follows the log file and streams new entries
func (l *Logger) TailLogs(out io.Writer, stop <-chan struct{}) error {
	file, err := os.Open(l.config.LogFile)
	if err != nil {
		return fmt.Errorf("failed to open log file: %w", err)
	}
	defer func() {
		if err := file.Close(); err != nil {
			l.Error("Failed to close log file", err, nil)
		}
	}()

	// Seek to end of file
	if _, err := file.Seek(0, io.SeekEnd); err != nil {
		return fmt.Errorf("failed to seek to end of file: %w", err)
	}

	scanner := bufio.NewScanner(file)
	for {
		select {
		case <-stop:
			return nil
		default:
			if scanner.Scan() {
				if _, err := fmt.Fprintln(out, scanner.Text()); err != nil {
					return fmt.Errorf("failed to write log entry: %w", err)
				}
			} else {
				// Wait for more data
				time.Sleep(100 * time.Millisecond)
			}
		}
	}
}

// matchesQuery checks if a log entry matches the given query
func matchesQuery(entry LogEntry, query *LogQuery) bool {
	// Parse entry time
	entryTime, err := time.Parse(time.RFC3339, entry.Time)
	if err != nil {
		return false
	}

	// Check time range
	if !query.StartTime.IsZero() && entryTime.Before(query.StartTime) {
		return false
	}
	if !query.EndTime.IsZero() && entryTime.After(query.EndTime) {
		return false
	}

	// Check level
	if query.Level != "" && !strings.EqualFold(entry.Level, query.Level) {
		return false
	}

	// Check component
	if query.Component != "" {
		component, ok := entry.Fields["component"].(string)
		if !ok || !strings.EqualFold(component, query.Component) {
			return false
		}
	}

	// Check contains
	if query.Contains != "" {
		contains := strings.ToLower(query.Contains)
		if !strings.Contains(strings.ToLower(entry.Message), contains) &&
			!strings.Contains(strings.ToLower(entry.Error), contains) {
			return false
		}
	}

	return true
}
