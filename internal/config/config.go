// Package config implements configuration management for Flow Control.
package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"flow-control/internal/types"
)

// Config represents the application configuration
type Config struct {
	// Server configuration
	Server struct {
		Host string `json:"host"`
		Port int    `json:"port"`
	} `json:"server"`

	// Database configuration
	Database struct {
		Path string `json:"path"`
	} `json:"database"`

	// Logging configuration
	Logging struct {
		Level  string `json:"level"`
		Format string `json:"format"`
	} `json:"logging"`
}

var defaultConfig = Config{
	Server: struct {
		Host string `json:"host"`
		Port int    `json:"port"`
	}{
		Host: "0.0.0.0",
		Port: 8080,
	},
	Database: struct {
		Path string `json:"path"`
	}{
		Path: "data/flows.db",
	},
	Logging: struct {
		Level  string `json:"level"`
		Format string `json:"format"`
	}{
		Level:  "info",
		Format: "console",
	},
}

// Validate checks if the configuration is valid
func (c *Config) Validate() error {
	// Validate server configuration
	if c.Server.Port < 1 || c.Server.Port > 65535 {
		return fmt.Errorf("invalid port number: %d", c.Server.Port)
	}

	// Validate database configuration
	if c.Database.Path == "" {
		return fmt.Errorf("database path cannot be empty")
	}
	if !strings.HasSuffix(c.Database.Path, ".db") {
		return fmt.Errorf("database path must end with .db")
	}

	// Validate logging configuration
	validLevels := map[string]bool{
		"trace": true,
		"debug": true,
		"info":  true,
		"warn":  true,
		"error": true,
	}
	if !validLevels[strings.ToLower(c.Logging.Level)] {
		return fmt.Errorf("invalid log level: %s", c.Logging.Level)
	}

	validFormats := map[string]bool{
		"console": true,
		"json":    true,
	}
	if !validFormats[strings.ToLower(c.Logging.Format)] {
		return fmt.Errorf("invalid log format: %s", c.Logging.Format)
	}

	return nil
}

// Load loads the configuration from a file
func Load(path string, log types.Logger) (*Config, error) {
	log.Debug("Loading configuration", types.Fields{
		"function": "Load",
		"path":     path,
	})

	// Start with default config
	config := defaultConfig

	// If no path provided, use default
	if path == "" {
		log.Info("No config file provided, using defaults", types.Fields{
			"function": "Load",
		})
		return &config, nil
	}

	// Read config file
	data, err := os.ReadFile(path)
	if err != nil {
		log.Error("Failed to read config file", err, types.Fields{
			"function": "Load",
			"path":     path,
		})
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	// Parse config file
	if err := json.Unmarshal(data, &config); err != nil {
		log.Error("Failed to parse config file", err, types.Fields{
			"function": "Load",
			"path":     path,
		})
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	// Validate configuration
	if err := config.Validate(); err != nil {
		log.Error("Invalid configuration", err, types.Fields{
			"function": "Load",
			"path":     path,
		})
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	// Ensure database directory exists
	dbDir := filepath.Dir(config.Database.Path)
	if err := os.MkdirAll(dbDir, 0o755); err != nil {
		log.Error("Failed to create database directory", err, types.Fields{
			"function": "Load",
			"path":     dbDir,
		})
		return nil, fmt.Errorf("failed to create database directory: %w", err)
	}

	log.Info("Configuration loaded successfully", types.Fields{
		"function": "Load",
		"path":     path,
	})

	return &config, nil
}
