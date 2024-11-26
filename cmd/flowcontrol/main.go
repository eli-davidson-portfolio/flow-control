/*
Package main is the entry point for the Flow Control application.
It initializes the configuration, logger, store, and server components.
*/
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"flow-control/internal/config"
	"flow-control/internal/docserver"
	"flow-control/internal/logger"
	"flow-control/internal/server"
	"flow-control/internal/store"
)

func main() {
	// Create logger
	log := logger.New()

	// Load configuration
	cfg, err := config.Load("", log)
	if err != nil {
		log.Error("Failed to load configuration", err, nil)
		os.Exit(1)
	}

	// Create store
	db, err := store.New(cfg.Database.Path, log)
	if err != nil {
		log.Error("Failed to create store", err, nil)
		os.Exit(1)
	}

	// Create server
	srv := server.New(db, log)

	// Create documentation server
	docs := docserver.New(log)
	srv.Mount("/", docs.Routes())

	// Create HTTP server
	httpServer := &http.Server{
		Addr:    fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port),
		Handler: srv,
	}

	// Handle graceful shutdown
	done := make(chan bool)
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-quit
		log.Info("Server is shutting down...", nil)

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		if err := httpServer.Shutdown(ctx); err != nil {
			log.Error("Failed to gracefully shutdown server", err, nil)
		}

		if err := db.Close(); err != nil {
			log.Error("Failed to close database", err, nil)
		}

		close(done)
	}()

	// Start server
	log.Info("Server is starting...", nil)
	if err := httpServer.ListenAndServe(); err != http.ErrServerClosed {
		log.Error("Failed to start server", err, nil)
		if err := db.Close(); err != nil {
			log.Error("Failed to close database", err, nil)
		}
		os.Exit(1)
	}

	<-done
	log.Info("Server stopped", nil)
}
