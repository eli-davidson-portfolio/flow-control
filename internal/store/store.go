package store

import (
	"context"
	"database/sql"
	"fmt"
	"sync"

	"flow-control/internal/types"

	_ "github.com/mattn/go-sqlite3"
)

// Store represents the data store
type Store struct {
	db     *sql.DB
	logger types.Logger
	mu     sync.RWMutex
}

// Config holds store configuration
type Config struct {
	DBPath string
}

// New creates a new store instance with the given configuration
func New(dbPath string, logger types.Logger) (*Store, error) {
	if logger == nil {
		return nil, fmt.Errorf("logger is required")
	}

	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Test connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	store := &Store{
		db:     db,
		logger: logger,
	}

	// Initialize schema
	if err := store.initSchema(); err != nil {
		return nil, fmt.Errorf("failed to initialize schema: %w", err)
	}

	return store, nil
}

// Close closes the database connection
func (s *Store) Close() error {
	s.logger.Info("Closing database connection", types.LogFields{
		"component": "store",
	})
	return s.db.Close()
}

// initSchema initializes the database schema
func (s *Store) initSchema() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.logger.Info("Initializing database schema", types.LogFields{
		"component": "store",
	})

	schema := `
	CREATE TABLE IF NOT EXISTS flows (
		id TEXT PRIMARY KEY,
		name TEXT NOT NULL,
		description TEXT,
		version TEXT NOT NULL,
		config JSON,
		status TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS flow_steps (
		id TEXT PRIMARY KEY,
		flow_id TEXT NOT NULL,
		name TEXT NOT NULL,
		type TEXT NOT NULL,
		config JSON,
		position INTEGER NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (flow_id) REFERENCES flows(id) ON DELETE CASCADE
	);

	CREATE INDEX IF NOT EXISTS idx_flow_steps_flow_id ON flow_steps(flow_id);
	`

	if _, err := s.db.Exec(schema); err != nil {
		return fmt.Errorf("failed to create schema: %w", err)
	}

	return nil
}

// WithTx executes a function within a transaction
func (s *Store) WithTx(ctx context.Context, fn func(*sql.Tx) error) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}

	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback()
			panic(p)
		}
	}()

	if err := fn(tx); err != nil {
		if rbErr := tx.Rollback(); rbErr != nil {
			s.logger.Error("Failed to rollback transaction", rbErr, types.LogFields{
				"component": "store",
			})
		}
		return err
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	return nil
}

