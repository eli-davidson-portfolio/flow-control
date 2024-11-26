/*
Package server implements the HTTP server and API endpoints for Flow Control.
It provides REST endpoints for flow management and real-time updates via SSE.
*/
package server

import (
	"encoding/json"
	"fmt"
	"net/http"

	// Import swagger docs
	_ "flow-control/docs"
	"flow-control/internal/store"
	"flow-control/internal/types"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	httpSwagger "github.com/swaggo/http-swagger"
)

// Server represents the HTTP server
type Server struct {
	router chi.Router
	store  *store.Store
	log    types.Logger
}

// New creates a new Server instance
func New(s *store.Store, log types.Logger) *Server {
	srv := &Server{
		router: chi.NewRouter(),
		store:  s,
		log:    log,
	}

	srv.setupRoutes()
	return srv
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.router.ServeHTTP(w, r)
}

func (s *Server) setupRoutes() {
	s.router.Use(middleware.Logger)
	s.router.Use(middleware.Recoverer)

	// Root handler redirects to documentation
	s.router.Get("/", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/docs", http.StatusFound)
	})

	// Swagger documentation
	s.router.Get("/api/swagger/*", httpSwagger.Handler(
		httpSwagger.URL("/api/swagger/doc.json"),
	))

	// API routes
	s.router.Route("/api", func(r chi.Router) {
		r.Get("/flows", s.handleListFlows)
		r.Post("/flows", s.handleCreateFlow)
		r.Get("/flows/{id}", s.handleGetFlow)
		r.Put("/flows/{id}", s.handleUpdateFlow)
		r.Delete("/flows/{id}", s.handleDeleteFlow)
		r.Put("/flows/{id}/status", s.handleUpdateFlowStatus)
		r.Get("/flows/{id}/events", s.handleFlowEvents)
	})
}

// Mount mounts a sub-router at the specified path
func (s *Server) Mount(path string, handler http.Handler) {
	s.router.Mount(path, handler)
}

// @Summary List all flows
// @Description Get a list of all flows
// @Tags flows
// @Accept json
// @Produce json
// @Success 200 {array} types.RuntimeFlow
// @Router /flows [get]
func (s *Server) handleListFlows(w http.ResponseWriter, r *http.Request) {
	flows, err := s.store.ListFlows()
	if err != nil {
		s.log.Error("Failed to list flows", err, types.Fields{
			"function": "handleListFlows",
		})
		http.Error(w, "Failed to list flows", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(flows); err != nil {
		s.log.Error("Failed to encode flows", err, types.Fields{
			"function": "handleListFlows",
		})
		http.Error(w, "Failed to encode flows", http.StatusInternalServerError)
		return
	}
}

// @Summary Create a new flow
// @Description Create a new flow with the provided configuration
// @Tags flows
// @Accept json
// @Produce json
// @Param flow body types.RuntimeFlow true "Flow configuration"
// @Success 201 {object} types.RuntimeFlow
// @Router /flows [post]
func (s *Server) handleCreateFlow(w http.ResponseWriter, r *http.Request) {
	var flow types.RuntimeFlow
	if err := json.NewDecoder(r.Body).Decode(&flow); err != nil {
		s.log.Error("Failed to decode flow", err, types.Fields{
			"function": "handleCreateFlow",
		})
		http.Error(w, "Invalid flow data", http.StatusBadRequest)
		return
	}

	if err := s.store.CreateFlow(&flow); err != nil {
		s.log.Error("Failed to create flow", err, types.Fields{
			"function": "handleCreateFlow",
			"flow_id":  flow.ID,
		})
		http.Error(w, "Failed to create flow", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	if err := json.NewEncoder(w).Encode(flow); err != nil {
		s.log.Error("Failed to encode flow", err, types.Fields{
			"function": "handleCreateFlow",
			"flow_id":  flow.ID,
		})
		http.Error(w, "Failed to encode flow", http.StatusInternalServerError)
		return
	}
}

// @Summary Get a flow by ID
// @Description Get a flow's details by its ID
// @Tags flows
// @Accept json
// @Produce json
// @Param id path string true "Flow ID"
// @Success 200 {object} types.RuntimeFlow
// @Router /flows/{id} [get]
func (s *Server) handleGetFlow(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	flow, err := s.store.GetFlow(id)
	if err != nil {
		s.log.Error("Failed to get flow", err, types.Fields{
			"function": "handleGetFlow",
			"flow_id":  id,
		})
		http.Error(w, "Flow not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(flow); err != nil {
		s.log.Error("Failed to encode flow", err, types.Fields{
			"function": "handleGetFlow",
			"flow_id":  id,
		})
		http.Error(w, "Failed to encode flow", http.StatusInternalServerError)
		return
	}
}

// @Summary Update a flow
// @Description Update an existing flow's configuration
// @Tags flows
// @Accept json
// @Produce json
// @Param id path string true "Flow ID"
// @Param flow body types.RuntimeFlow true "Updated flow configuration"
// @Success 200 {object} types.RuntimeFlow
// @Router /flows/{id} [put]
func (s *Server) handleUpdateFlow(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var flow types.RuntimeFlow
	if err := json.NewDecoder(r.Body).Decode(&flow); err != nil {
		s.log.Error("Failed to decode flow", err, types.Fields{
			"function": "handleUpdateFlow",
			"flow_id":  id,
		})
		http.Error(w, "Invalid flow data", http.StatusBadRequest)
		return
	}

	flow.ID = id
	if err := s.store.UpdateFlow(&flow); err != nil {
		s.log.Error("Failed to update flow", err, types.Fields{
			"function": "handleUpdateFlow",
			"flow_id":  id,
		})
		http.Error(w, "Failed to update flow", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(flow); err != nil {
		s.log.Error("Failed to encode flow", err, types.Fields{
			"function": "handleUpdateFlow",
			"flow_id":  id,
		})
		http.Error(w, "Failed to encode flow", http.StatusInternalServerError)
		return
	}
}

// @Summary Delete a flow
// @Description Delete a flow by its ID
// @Tags flows
// @Accept json
// @Produce json
// @Param id path string true "Flow ID"
// @Success 204 "No Content"
// @Router /flows/{id} [delete]
func (s *Server) handleDeleteFlow(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := s.store.DeleteFlow(id); err != nil {
		s.log.Error("Failed to delete flow", err, types.Fields{
			"function": "handleDeleteFlow",
			"flow_id":  id,
		})
		http.Error(w, "Failed to delete flow", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// @Summary Update flow status
// @Description Update a flow's status
// @Tags flows
// @Accept json
// @Produce json
// @Param id path string true "Flow ID"
// @Param status body string true "New status"
// @Success 200 "OK"
// @Router /flows/{id}/status [put]
func (s *Server) handleUpdateFlowStatus(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var status struct {
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&status); err != nil {
		s.log.Error("Failed to decode status", err, types.Fields{
			"function": "handleUpdateFlowStatus",
			"flow_id":  id,
		})
		http.Error(w, "Invalid status data", http.StatusBadRequest)
		return
	}

	if err := s.store.UpdateFlowStatus(id, status.Status); err != nil {
		s.log.Error("Failed to update flow status", err, types.Fields{
			"function": "handleUpdateFlowStatus",
			"flow_id":  id,
			"status":   status.Status,
		})
		http.Error(w, "Failed to update flow status", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

// @Summary Get flow events
// @Description Get real-time events for a flow via SSE
// @Tags flows
// @Accept json
// @Produce text/event-stream
// @Param id path string true "Flow ID"
// @Success 200 {object} types.FlowEvent
// @Router /flows/{id}/events [get]
func (s *Server) handleFlowEvents(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	// Set headers for SSE
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	// Create event channel
	events := make(chan types.FlowEvent)
	defer close(events)

	// Start event stream
	flusher, ok := w.(http.Flusher)
	if !ok {
		s.log.Error("Streaming not supported", nil, types.Fields{
			"function": "handleFlowEvents",
			"flow_id":  id,
		})
		http.Error(w, "Streaming not supported", http.StatusInternalServerError)
		return
	}

	// Keep connection alive until client disconnects
	go func() {
		<-r.Context().Done()
		s.log.Info("Client disconnected", types.Fields{
			"function": "handleFlowEvents",
			"flow_id":  id,
		})
	}()

	// Send events
	for event := range events {
		data, err := json.Marshal(event)
		if err != nil {
			s.log.Error("Failed to marshal event", err, types.Fields{
				"function": "handleFlowEvents",
				"flow_id":  id,
			})
			continue
		}

		if _, err := fmt.Fprintf(w, "data: %s\n\n", data); err != nil {
			s.log.Error("Failed to write event", err, types.Fields{
				"function": "handleFlowEvents",
				"flow_id":  id,
			})
			return
		}
		flusher.Flush()
	}
}
