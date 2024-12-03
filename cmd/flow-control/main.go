package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"flow-control/internal/logger"
	"flow-control/internal/server"
	"flow-control/internal/store"
	"flow-control/internal/types"
)

// config holds application configuration
type config struct {
	env      string
	port     string
	dbPath   string
	logLevel string
}

func main() {
	// Parse configuration
	cfg := parseConfig()

	// Create root context
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize logger
	log := logger.New(logger.Config{
		LogFile:    "logs/flow-control.log",
		MaxSize:    100,
		MaxBackups: 5,
		MaxAge:     30,
		Compress:   true,
		Level:      cfg.logLevel,
	})

	// Initialize store
	store, err := store.New(cfg.dbPath, log)
	if err != nil {
		log.Error("Failed to initialize store", err, types.LogFields{
			"component": "main",
			"dbPath":    cfg.dbPath,
		})
		os.Exit(1)
	}
	defer store.Close()

	// Create and configure server
	srv := server.New(&server.Config{
		Store:  store,
		Logger: log,
		Port:   cfg.port,
		Env:    cfg.env,
	})

	// Start server
	go func() {
		addr := fmt.Sprintf(":%s", cfg.port)
		log.Info("Starting server", types.LogFields{
			"component":   "main",
			"address":     addr,
			"environment": cfg.env,
		})

		server := &http.Server{
			Addr:              addr,
			Handler:           srv,
			ReadTimeout:       5 * time.Second,
			WriteTimeout:      10 * time.Second,
			IdleTimeout:       15 * time.Second,
			ReadHeaderTimeout: 2 * time.Second,
		}

		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Error("Server error", err, types.LogFields{
				"component": "main",
			})
			cancel()
		}
	}()

	// Handle shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	select {
	case <-ctx.Done():
		log.Info("Context cancelled", types.LogFields{
			"component": "main",
		})
	case sig := <-quit:
		log.Info("Shutdown signal received", types.LogFields{
			"component": "main",
			"signal":    sig.String(),
		})
		cancel()
	}

	// Graceful shutdown
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("Server shutdown error", err, types.LogFields{
			"component": "main",
		})
	}

	log.Info("Server stopped", types.LogFields{
		"component": "main",
	})
}

func parseConfig() config {
	cfg := config{}

	flag.StringVar(&cfg.env, "env", "dev", "Environment (dev/staging/prod)")
	flag.StringVar(&cfg.port, "port", "8081", "Port to listen on")
	flag.StringVar(&cfg.dbPath, "db", "data/flows.db", "Database path")
	flag.StringVar(&cfg.logLevel, "log-level", "info", "Log level (debug/info/warn/error)")
	flag.Parse()

	return cfg
} 