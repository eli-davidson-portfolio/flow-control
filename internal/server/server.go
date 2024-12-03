/*
Package server implements the HTTP server for Flow Control.

Core Responsibilities:
- Provides HTTP API endpoints
- Handles request routing and middleware
- Manages server lifecycle
- Implements health checks

Dependencies:
- flow-control/internal/store: For data persistence
- flow-control/internal/types: For type definitions
- github.com/go-chi/chi/v5: For HTTP routing
*/
package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"flow-control/internal/store"
	"flow-control/internal/types"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

// Server represents the HTTP server
type Server struct {
	router chi.Router
	store  *store.Store
	logger types.Logger
}

// Config holds server configuration
type Config struct {
	Store  *store.Store
	Logger types.Logger
	Port   string
	Env    string
}

// New creates a new server instance
func New(config *Config) *Server {
	if config == nil {
		panic("config is required")
	}
	if config.Store == nil {
		panic("store is required")
	}
	if config.Logger == nil {
		panic("logger is required")
	}

	s := &Server{
		router: chi.NewRouter(),
		store:  config.Store,
		logger: config.Logger,
	}

	s.setupMiddleware()
	s.setupRoutes()

	return s
}

// ServeHTTP implements http.Handler
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.router.ServeHTTP(w, r)
}

// Shutdown gracefully shuts down the server
func (s *Server) Shutdown(ctx context.Context) error {
	s.logger.Info("Shutting down server", types.LogFields{
		"component": "server",
	})
	return nil
}

func (s *Server) setupMiddleware() {
	s.router.Use(middleware.RequestID)
	s.router.Use(middleware.RealIP)
	s.router.Use(middleware.Logger)
	s.router.Use(middleware.Recoverer)
	s.router.Use(middleware.Timeout(60 * time.Second))
}

func (s *Server) setupRoutes() {
	s.router.Get("/health", s.handleHealth())
	s.router.Route("/api/v1", func(r chi.Router) {
		r.Route("/flows", func(r chi.Router) {
			r.Get("/", s.handleListFlows())
			r.Post("/", s.handleCreateFlow())
			r.Route("/{id}", func(r chi.Router) {
				r.Get("/", s.handleGetFlow())
				r.Put("/", s.handleUpdateFlow())
				r.Delete("/", s.handleDeleteFlow())
			})
		})
	})
}

func (s *Server) handleHealth() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		s.logger.Debug("Health check", types.LogFields{
			"component": "server",
			"path":      "/health",
		})

		response := map[string]string{
			"status": "ok",
			"time":   time.Now().UTC().Format(time.RFC3339),
		}

		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(response); err != nil {
			s.logger.Error("Failed to encode health response", err, types.LogFields{
				"component": "server",
			})
			http.Error(w, "Internal server error", http.StatusInternalServerError)
		}
	}
}

func (s *Server) handleListFlows() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		s.logger.Debug("List flows", types.LogFields{
			"component": "server",
			"path":      "/api/v1/flows",
		})

		// TODO: Implement flow listing
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "[]")
	}
}

func (s *Server) handleCreateFlow() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		s.logger.Debug("Create flow", types.LogFields{
			"component": "server",
			"path":      "/api/v1/flows",
		})

		// TODO: Implement flow creation
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		fmt.Fprintf(w, "{}")
	}
}

func (s *Server) handleGetFlow() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		s.logger.Debug("Get flow", types.LogFields{
			"component": "server",
			"path":      fmt.Sprintf("/api/v1/flows/%s", id),
			"flow_id":   id,
		})

		// TODO: Implement flow retrieval
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "{}")
	}
}

func (s *Server) handleUpdateFlow() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		s.logger.Debug("Update flow", types.LogFields{
			"component": "server",
			"path":      fmt.Sprintf("/api/v1/flows/%s", id),
			"flow_id":   id,
		})

		// TODO: Implement flow update
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "{}")
	}
}

func (s *Server) handleDeleteFlow() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		s.logger.Debug("Delete flow", types.LogFields{
			"component": "server",
			"path":      fmt.Sprintf("/api/v1/flows/%s", id),
			"flow_id":   id,
		})

		// TODO: Implement flow deletion
		w.WriteHeader(http.StatusNoContent)
	}
}
