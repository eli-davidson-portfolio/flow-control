package config

import (
	"os"
	"strconv"

	"flow-control/internal/types"
)

// Config represents the application configuration
type Config struct {
	Server   ServerConfig   `json:"server"`
	Database DatabaseConfig `json:"database"`
}

// ServerConfig represents server configuration
type ServerConfig struct {
	Host string `json:"host"`
	Port int    `json:"port"`
}

// DatabaseConfig represents database configuration
type DatabaseConfig struct {
	Path string `json:"path"`
}

// New creates a new default configuration
func New() *Config {
	return &Config{
		Server: ServerConfig{
			Host: "0.0.0.0",
			Port: 8080,
		},
		Database: DatabaseConfig{
			Path: "data/flows.db",
		},
	}
}

// Load loads configuration from environment variables
func Load(configPath string, log types.Logger) (*Config, error) {
	cfg := New()

	// Load server configuration
	if host := os.Getenv("SERVER_HOST"); host != "" {
		cfg.Server.Host = host
	}

	if portStr := os.Getenv("APP_PORT"); portStr != "" {
		port, err := strconv.Atoi(portStr)
		if err != nil {
			log.Error("Invalid port number", err, types.Fields{
				"port": portStr,
			})
			return nil, err
		}
		cfg.Server.Port = port
	}

	// Load database configuration
	if dbPath := os.Getenv("DB_PATH"); dbPath != "" {
		cfg.Database.Path = dbPath
	}

	log.Info("Configuration loaded", types.Fields{
		"server_host": cfg.Server.Host,
		"server_port": cfg.Server.Port,
		"db_path":     cfg.Database.Path,
	})

	return cfg, nil
}
