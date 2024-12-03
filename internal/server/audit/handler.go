package audit

import (
	"database/sql"
	"encoding/json"
	"html/template"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
)

// Handler handles audit-related HTTP routes
type Handler struct {
	db       *sql.DB
	tmpl     *template.Template
	dbPath   string
	router   chi.Router
}

// NewHandler creates a new audit handler
func NewHandler(db *sql.DB, tmpl *template.Template, dbPath string) *Handler {
	h := &Handler{
		db:     db,
		tmpl:   tmpl,
		dbPath: dbPath,
		router: chi.NewRouter(),
	}
	return h
}

// RegisterRoutes registers audit routes on the given router
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Route("/audit", func(r chi.Router) {
		r.Get("/", h.handleAuditDashboard)
		r.Get("/files", h.handleListFiles)
		r.Get("/files/unused", h.handleListUnusedFiles)
		r.Get("/files/{id}", h.handleGetFile)
		r.Post("/files/{id}/mark-used", h.handleMarkFileUsed)
		r.Post("/files/{id}/mark-unused", h.handleMarkFileUnused)
	})
}

// handleAuditDashboard renders the audit dashboard
func (h *Handler) handleAuditDashboard(w http.ResponseWriter, r *http.Request) {
	data := struct {
		Title     string
		Files     []File
		UpdatedAt time.Time
	}{
		Title:     "Audit Dashboard",
		UpdatedAt: time.Now(),
	}

	files, err := h.listFiles()
	if err != nil {
		http.Error(w, "Failed to list files", http.StatusInternalServerError)
		return
	}
	data.Files = files

	if err := h.tmpl.ExecuteTemplate(w, "audit.html", data); err != nil {
		http.Error(w, "Failed to render template", http.StatusInternalServerError)
		return
	}
}

// File represents a file in the audit system
type File struct {
	ID          int       `json:"id"`
	Path        string    `json:"path"`
	Type        string    `json:"type"`
	Status      string    `json:"status"`
	LastUsed    time.Time `json:"last_used"`
	LastChecked time.Time `json:"last_checked"`
}

// listFiles returns all files in the audit system
func (h *Handler) listFiles() ([]File, error) {
	query := `
		SELECT id, path, type, status, last_used, last_checked
		FROM files
		ORDER BY path ASC
	`

	rows, err := h.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var files []File
	for rows.Next() {
		var f File
		err := rows.Scan(&f.ID, &f.Path, &f.Type, &f.Status, &f.LastUsed, &f.LastChecked)
		if err != nil {
			return nil, err
		}
		files = append(files, f)
	}

	return files, rows.Err()
}

// handleListFiles returns a JSON list of all files
func (h *Handler) handleListFiles(w http.ResponseWriter, r *http.Request) {
	files, err := h.listFiles()
	if err != nil {
		http.Error(w, "Failed to list files", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(files)
}

// handleListUnusedFiles returns a JSON list of unused files
func (h *Handler) handleListUnusedFiles(w http.ResponseWriter, r *http.Request) {
	query := `
		SELECT id, path, type, status, last_used, last_checked
		FROM files
		WHERE status = 'unused'
		ORDER BY path ASC
	`

	rows, err := h.db.Query(query)
	if err != nil {
		http.Error(w, "Failed to list unused files", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var files []File
	for rows.Next() {
		var f File
		err := rows.Scan(&f.ID, &f.Path, &f.Type, &f.Status, &f.LastUsed, &f.LastChecked)
		if err != nil {
			http.Error(w, "Failed to scan file", http.StatusInternalServerError)
			return
		}
		files = append(files, f)
	}

	if err := rows.Err(); err != nil {
		http.Error(w, "Error iterating files", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(files)
}

// handleGetFile returns details for a specific file
func (h *Handler) handleGetFile(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	query := `
		SELECT id, path, type, status, last_used, last_checked
		FROM files
		WHERE id = ?
	`

	var f File
	err := h.db.QueryRow(query, id).Scan(
		&f.ID, &f.Path, &f.Type, &f.Status, &f.LastUsed, &f.LastChecked,
	)
	if err == sql.ErrNoRows {
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, "Failed to get file", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(f)
}

// handleMarkFileUsed marks a file as used
func (h *Handler) handleMarkFileUsed(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	query := `
		UPDATE files
		SET status = 'active', last_used = ?
		WHERE id = ?
	`

	_, err := h.db.Exec(query, time.Now(), id)
	if err != nil {
		http.Error(w, "Failed to mark file as used", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

// handleMarkFileUnused marks a file as unused
func (h *Handler) handleMarkFileUnused(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	query := `
		UPDATE files
		SET status = 'unused', last_checked = ?
		WHERE id = ?
	`

	_, err := h.db.Exec(query, time.Now(), id)
	if err != nil {
		http.Error(w, "Failed to mark file as unused", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
} 