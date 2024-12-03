package bridge

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"time"
)

// Result codes matching bash implementation
const (
	ResultSuccess = 0
	ResultFailure = 1
	ResultSkip    = 2
	ResultError   = 3
)

// HandoffData represents the test handoff state
type HandoffData struct {
	ProtocolVersion string          `json:"protocol_version"`
	Level          int             `json:"level"`
	State          json.RawMessage `json:"state"`
	Metadata       json.RawMessage `json:"metadata"`
	Timestamp      time.Time       `json:"timestamp"`
}

// TestResult represents a single test result
type TestResult struct {
	Name     string    `json:"name"`
	Result   int       `json:"result"`
	Output   string    `json:"output"`
	Duration int64     `json:"duration"`
	Time     time.Time `json:"timestamp"`
}

// Bridge handles communication between bash and Go test frameworks
type Bridge struct {
	db *sql.DB
}

// NewBridge creates a new bridge instance
func NewBridge(dbPath string) (*Bridge, error) {
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	return &Bridge{db: db}, nil
}

// LoadHandoff loads the handoff data from the handoff file
func (b *Bridge) LoadHandoff(path string) (*HandoffData, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read handoff file: %w", err)
	}

	var handoff HandoffData
	if err := json.Unmarshal(data, &handoff); err != nil {
		return nil, fmt.Errorf("failed to parse handoff data: %w", err)
	}

	return &handoff, nil
}

// SaveResult saves the test results back to the database
func (b *Bridge) SaveResult(stateID int64, result *TestResult) error {
	_, err := b.db.Exec(`
		INSERT INTO test_results (state_id, test_name, result, output, duration, timestamp)
		VALUES (?, ?, ?, ?, ?, ?)
	`, stateID, result.Name, result.Result, result.Output, result.Duration, result.Time)

	if err != nil {
		return fmt.Errorf("failed to save test result: %w", err)
	}

	return nil
}

// RecordTransition records a framework transition
func (b *Bridge) RecordTransition(from, to string, level int, status int, stateData interface{}) error {
	stateJSON, err := json.Marshal(stateData)
	if err != nil {
		return fmt.Errorf("failed to marshal state data: %w", err)
	}

	_, err = b.db.Exec(`
		INSERT INTO framework_transitions (from_framework, to_framework, level, status, state_data, timestamp)
		VALUES (?, ?, ?, ?, ?, datetime('now'))
	`, from, to, level, status, string(stateJSON))

	if err != nil {
		return fmt.Errorf("failed to record transition: %w", err)
	}

	return nil
}

// Close closes the database connection
func (b *Bridge) Close() error {
	return b.db.Close()
} 