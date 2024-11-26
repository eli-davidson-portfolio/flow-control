package config_test

import (
	"os"
	"testing"

	"flow-control/internal/config"
	"flow-control/internal/logger"

	"github.com/stretchr/testify/require"
)

func TestConfig(t *testing.T) {
	// Create logger
	log := logger.New()

	// Test default config
	t.Run("default config", func(t *testing.T) {
		cfg, err := config.Load("", log)
		require.NoError(t, err)
		require.NotNil(t, cfg)

		// Check default values
		require.Equal(t, "localhost", cfg.Server.Host)
		require.Equal(t, 8080, cfg.Server.Port)
		require.Equal(t, "data/flows.db", cfg.Database.Path)
	})

	// Test loading from file
	t.Run("load from file", func(t *testing.T) {
		// Create test config file
		content := `{
			"server": {
				"host": "127.0.0.1",
				"port": 9090
			},
			"database": {
				"path": "test.db"
			}
		}`
		tmpfile, err := os.CreateTemp("", "config-*.json")
		require.NoError(t, err)
		defer func() {
			if err := os.Remove(tmpfile.Name()); err != nil {
				t.Errorf("Failed to remove temp file: %v", err)
			}
		}()

		_, err = tmpfile.WriteString(content)
		require.NoError(t, err)
		err = tmpfile.Close()
		require.NoError(t, err)

		// Load config
		cfg, err := config.Load(tmpfile.Name(), log)
		require.NoError(t, err)
		require.NotNil(t, cfg)

		// Check values
		require.Equal(t, "127.0.0.1", cfg.Server.Host)
		require.Equal(t, 9090, cfg.Server.Port)
		require.Equal(t, "test.db", cfg.Database.Path)
	})

	// Test invalid config file
	t.Run("invalid config file", func(t *testing.T) {
		// Create invalid config file
		content := `{
			"server": {
				"host": 123,
				"port": "invalid"
			}
		}`
		tmpfile, err := os.CreateTemp("", "config-*.json")
		require.NoError(t, err)
		defer func() {
			if err := os.Remove(tmpfile.Name()); err != nil {
				t.Errorf("Failed to remove temp file: %v", err)
			}
		}()

		_, err = tmpfile.WriteString(content)
		require.NoError(t, err)
		err = tmpfile.Close()
		require.NoError(t, err)

		// Load config
		_, err = config.Load(tmpfile.Name(), log)
		require.Error(t, err)
	})

	// Test nonexistent file
	t.Run("nonexistent file", func(t *testing.T) {
		_, err := config.Load("nonexistent.json", log)
		require.Error(t, err)
	})
}
