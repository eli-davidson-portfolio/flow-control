package store_test

import (
	"os"
	"testing"

	"flow-control/internal/logger"
	"flow-control/internal/store"
	"flow-control/internal/types"

	"github.com/stretchr/testify/require"
)

func TestStore(t *testing.T) {
	// Create test database
	dbPath := "test.db"
	defer func() {
		if err := os.Remove(dbPath); err != nil {
			t.Errorf("Failed to remove test database: %v", err)
		}
	}()

	// Create logger
	log := logger.New()

	// Create store
	db, err := store.New(dbPath, log)
	require.NoError(t, err)
	defer func() {
		if err := db.Close(); err != nil {
			t.Errorf("Failed to close store: %v", err)
		}
	}()

	// Test flow operations
	t.Run("flow operations", func(t *testing.T) {
		// Create test flow
		flow := &types.RuntimeFlow{
			ID:          "test-flow",
			Name:        "Test Flow",
			Description: "A test flow",
			Config:      "flow test {}",
			Status:      "stopped",
		}

		// Create flow
		err := db.CreateFlow(flow)
		require.NoError(t, err)

		// Get flow
		got, err := db.GetFlow(flow.ID)
		require.NoError(t, err)
		require.Equal(t, flow.ID, got.ID)
		require.Equal(t, flow.Name, got.Name)
		require.Equal(t, flow.Description, got.Description)
		require.Equal(t, flow.Config, got.Config)
		require.Equal(t, flow.Status, got.Status)

		// Update flow
		flow.Name = "Updated Flow"
		err = db.UpdateFlow(flow)
		require.NoError(t, err)

		// Get updated flow
		got, err = db.GetFlow(flow.ID)
		require.NoError(t, err)
		require.Equal(t, "Updated Flow", got.Name)

		// List flows
		flows, err := db.ListFlows()
		require.NoError(t, err)
		require.Len(t, flows, 1)
		require.Equal(t, flow.ID, flows[0].ID)

		// Delete flow
		err = db.DeleteFlow(flow.ID)
		require.NoError(t, err)

		// Verify deletion
		flows, err = db.ListFlows()
		require.NoError(t, err)
		require.Empty(t, flows)
	})

	// Test flow status
	t.Run("flow status", func(t *testing.T) {
		// Create test flow
		flow := &types.RuntimeFlow{
			ID:     "test-flow",
			Name:   "Test Flow",
			Status: "stopped",
		}

		// Create flow
		err := db.CreateFlow(flow)
		require.NoError(t, err)

		// Update status
		err = db.UpdateFlowStatus(flow.ID, "running")
		require.NoError(t, err)

		// Get flow
		got, err := db.GetFlow(flow.ID)
		require.NoError(t, err)
		require.Equal(t, "running", got.Status)

		// Clean up
		err = db.DeleteFlow(flow.ID)
		require.NoError(t, err)
	})
}
