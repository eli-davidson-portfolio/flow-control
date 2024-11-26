package store

import (
	"database/sql"
	"fmt"
	"time"

	"flow-control/internal/types"

	// Import sqlite3 driver for database connectivity
	_ "github.com/mattn/go-sqlite3"
)

// Store represents a SQLite-based flow store
type Store struct {
	db  *sql.DB
	log types.Logger
}

// New creates a new Store instance
func New(dbPath string, log types.Logger) (*Store, error) {
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		if closeErr := db.Close(); closeErr != nil {
			log.Error("Failed to close database after open error", closeErr, types.Fields{
				"function": "New",
				"path":     dbPath,
			})
		}
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	if err := db.Ping(); err != nil {
		if closeErr := db.Close(); closeErr != nil {
			log.Error("Failed to close database after ping error", closeErr, types.Fields{
				"function": "New",
				"path":     dbPath,
			})
		}
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	store := &Store{
		db:  db,
		log: log,
	}

	if err := store.createTables(); err != nil {
		if closeErr := db.Close(); closeErr != nil {
			log.Error("Failed to close database after table creation error", closeErr, types.Fields{
				"function": "New",
				"path":     dbPath,
			})
		}
		return nil, fmt.Errorf("failed to create tables: %w", err)
	}

	return store, nil
}

// Close closes the database connection
func (s *Store) Close() error {
	if err := s.db.Close(); err != nil {
		s.log.Error("Failed to close database", err, types.Fields{
			"function": "Close",
		})
		return fmt.Errorf("failed to close database: %w", err)
	}
	return nil
}

// CreateFlow creates a new flow in the store
func (s *Store) CreateFlow(flow *types.RuntimeFlow) error {
	flow.CreatedAt = time.Now()
	flow.UpdatedAt = flow.CreatedAt

	query := `
		INSERT INTO flows (id, name, description, version, config, status, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`

	_, err := s.db.Exec(query,
		flow.ID,
		flow.Name,
		flow.Description,
		flow.Version,
		flow.Config,
		flow.Status,
		flow.CreatedAt,

		flow.UpdatedAt,
	)

	if err != nil {
		s.log.Error("Failed to create flow", err, types.Fields{
			"function": "CreateFlow",
			"flow_id":  flow.ID,
		})
		return fmt.Errorf("failed to create flow: %w", err)
	}

	return nil
}

// GetFlow retrieves a flow by ID
func (s *Store) GetFlow(id string) (*types.RuntimeFlow, error) {
	query := `
		SELECT id, name, description, version, config, status, created_at, updated_at
		FROM flows
		WHERE id = ?
	`

	flow := &types.RuntimeFlow{}
	err := s.db.QueryRow(query, id).Scan(
		&flow.ID,
		&flow.Name,
		&flow.Description,
		&flow.Version,
		&flow.Config,
		&flow.Status,
		&flow.CreatedAt,
		&flow.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("flow not found: %s", id)
		}
		s.log.Error("Failed to get flow", err, types.Fields{
			"function": "GetFlow",
			"flow_id":  id,
		})
		return nil, fmt.Errorf("failed to get flow: %w", err)
	}

	return flow, nil
}

// ListFlows returns all flows in the store
func (s *Store) ListFlows() ([]*types.RuntimeFlow, error) {
	query := `
		SELECT id, name, description, version, config, status, created_at, updated_at
		FROM flows
		ORDER BY created_at DESC
	`

	rows, err := s.db.Query(query)
	if err != nil {
		s.log.Error("Failed to list flows", err, types.Fields{
			"function": "ListFlows",
		})
		return nil, fmt.Errorf("failed to list flows: %w", err)
	}
	defer func() {
		if err := rows.Close(); err != nil {
			s.log.Error("Failed to close rows", err, types.Fields{
				"function": "ListFlows",
			})
		}
	}()

	var flows []*types.RuntimeFlow
	for rows.Next() {
		flow := &types.RuntimeFlow{}
		err := rows.Scan(
			&flow.ID,
			&flow.Name,
			&flow.Description,
			&flow.Version,
			&flow.Config,
			&flow.Status,
			&flow.CreatedAt,
			&flow.UpdatedAt,
		)
		if err != nil {
			s.log.Error("Failed to scan flow", err, types.Fields{
				"function": "ListFlows",
			})
			return nil, fmt.Errorf("failed to scan flow: %w", err)
		}
		flows = append(flows, flow)
	}

	if err := rows.Err(); err != nil {
		s.log.Error("Error iterating flows", err, types.Fields{
			"function": "ListFlows",
		})
		return nil, fmt.Errorf("error iterating flows: %w", err)
	}

	return flows, nil
}

// UpdateFlow updates an existing flow
func (s *Store) UpdateFlow(flow *types.RuntimeFlow) error {
	flow.UpdatedAt = time.Now()

	query := `
		UPDATE flows
		SET name = ?, description = ?, version = ?, config = ?, status = ?, updated_at = ?
		WHERE id = ?
	`

	result, err := s.db.Exec(query,
		flow.Name,
		flow.Description,
		flow.Version,
		flow.Config,
		flow.Status,
		flow.UpdatedAt,
		flow.ID,
	)

	if err != nil {
		s.log.Error("Failed to update flow", err, types.Fields{
			"function": "UpdateFlow",
			"flow_id":  flow.ID,
		})
		return fmt.Errorf("failed to update flow: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		s.log.Error("Failed to get rows affected", err, types.Fields{
			"function": "UpdateFlow",
			"flow_id":  flow.ID,
		})
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("flow not found: %s", flow.ID)
	}

	return nil
}

// DeleteFlow deletes a flow by ID
func (s *Store) DeleteFlow(id string) error {
	query := `DELETE FROM flows WHERE id = ?`

	result, err := s.db.Exec(query, id)
	if err != nil {
		s.log.Error("Failed to delete flow", err, types.Fields{
			"function": "DeleteFlow",
			"flow_id":  id,
		})
		return fmt.Errorf("failed to delete flow: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		s.log.Error("Failed to get rows affected", err, types.Fields{
			"function": "DeleteFlow",
			"flow_id":  id,
		})
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("flow not found: %s", id)
	}

	return nil
}

// UpdateFlowStatus updates the status of a flow
func (s *Store) UpdateFlowStatus(id, status string) error {
	query := `
		UPDATE flows
		SET status = ?, updated_at = ?
		WHERE id = ?
	`

	result, err := s.db.Exec(query, status, time.Now(), id)
	if err != nil {
		s.log.Error("Failed to update flow status", err, types.Fields{
			"function": "UpdateFlowStatus",
			"flow_id":  id,
			"status":   status,
		})
		return fmt.Errorf("failed to update flow status: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		s.log.Error("Failed to get rows affected", err, types.Fields{
			"function": "UpdateFlowStatus",
			"flow_id":  id,
		})
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("flow not found: %s", id)
	}

	return nil
}

func (s *Store) createTables() error {
	query := `
		CREATE TABLE IF NOT EXISTS flows (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			description TEXT,
			version TEXT,
			config TEXT NOT NULL,
			status TEXT NOT NULL,
			created_at DATETIME NOT NULL,
			updated_at DATETIME NOT NULL
		)
	`

	_, err := s.db.Exec(query)
	if err != nil {
		s.log.Error("Failed to create tables", err, types.Fields{
			"function": "createTables",
		})
		return fmt.Errorf("failed to create tables: %w", err)
	}

	return nil
}
