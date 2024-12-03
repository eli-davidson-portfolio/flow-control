/*
Package main is the entry point for the Flow Control application.
It initializes the configuration, logger, store, and server components.
*/
package main

import (
	"context"
	"fmt"
	"html/template"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"flow-control/internal/config"
	"flow-control/internal/docserver"
	"flow-control/internal/logger"
	"flow-control/internal/server"
	"flow-control/internal/server/audit"
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
	store, err := store.New(cfg.Database.Path, log)
	if err != nil {
		log.Error("Failed to create store", err, nil)
		os.Exit(1)
	}
	defer store.Close()

	// Parse templates
	tmpl, err := parseTemplates()
	if err != nil {
		log.Error("Failed to parse templates", err, nil)
		os.Exit(1)
	}

	// Create server
	srv := server.New(store, log)

	// Create documentation server
	docs := docserver.New(log)
	srv.Mount("/docs", docs.Routes())

	// Create audit handler
	auditHandler := audit.NewHandler(store.DB(), tmpl, cfg.Database.Path)
	auditHandler.RegisterRoutes(srv.Router)

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

		if err := store.Close(); err != nil {
			log.Error("Failed to close database", err, nil)
		}

		close(done)
	}()

	// Start server
	log.Info("Server is starting...", nil)
	if err := httpServer.ListenAndServe(); err != http.ErrServerClosed {
		log.Error("Failed to start server", err, nil)
		if err := store.Close(); err != nil {
			log.Error("Failed to close database", err, nil)
		}
		os.Exit(1)
	}

	<-done
	log.Info("Server stopped", nil)
}

// parseTemplates parses all HTML templates
func parseTemplates() (*template.Template, error) {
	tmpl := template.New("")

	// Add template functions
	tmpl.Funcs(template.FuncMap{
		"formatTime": func(t time.Time) string {
			return t.Format("2006-01-02 15:04:05")
		},
		"json": func(v interface{}) string {
			// Simple JSON encoding for template data
			if v == nil {
				return "null"
			}
			switch val := v.(type) {
			case string:
				return fmt.Sprintf("%q", val)
			case int, int64, float64:
				return fmt.Sprintf("%v", val)
			default:
				return fmt.Sprintf("%q", fmt.Sprintf("%v", val))
			}
		},
	})

	// Parse all templates
	pattern := filepath.Join("web", "templates", "*.html")
	_, err := tmpl.ParseGlob(pattern)
	if err != nil {
		return nil, fmt.Errorf("failed to parse templates: %w", err)
	}

	return tmpl, nil
}
