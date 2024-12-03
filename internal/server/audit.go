package server

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/go-chi/chi/v5"
)

// AuditHandler handles audit-related HTTP endpoints
type AuditHandler struct {
	db       *sql.DB
	tmpl     *template.Template
	dataPath string
}

// NewAuditHandler creates a new audit handler
func NewAuditHandler(db *sql.DB, tmpl *template.Template, dataPath string) *AuditHandler {
	return &AuditHandler{
		db:       db,
		tmpl:     tmpl,
		dataPath: dataPath,
	}
}

// RegisterRoutes registers all audit-related routes
func (h *AuditHandler) RegisterRoutes(r chi.Router) {
	r.Get("/audit", h.handleAuditPage)
	r.Post("/audit/run", h.handleRunAudit)
	r.Get("/audit/overview", h.handleOverview)
	r.Get("/audit/issues", h.handleIssues)
	r.Get("/audit/structure", h.handleStructure)
	r.Get("/audit/quality", h.handleQuality)
	r.Get("/audit/usage", h.handleUsage)
	r.Get("/audit/documentation", h.handleDocumentation)
	r.Get("/audit/dependencies", h.handleDependencies)
	r.Get("/audit/export", h.handleExport)
}

// handleAuditPage renders the main audit page
func (h *AuditHandler) handleAuditPage(w http.ResponseWriter, r *http.Request) {
	h.tmpl.ExecuteTemplate(w, "audit.html", nil)
}

// handleRunAudit triggers a new audit
func (h *AuditHandler) handleRunAudit(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Run audit scripts
	scripts := []string{
		"scripts/audit/project_structure.sh",
		"scripts/audit/code_quality.sh",
		"scripts/audit/code_usage.sh",
	}

	success := true
	warning := false

	for _, script := range scripts {
		cmd := exec.Command(script)
		if err := cmd.Run(); err != nil {
			success = false
			warning = true
		}
	}

	// Return status
	w.Header().Set("Content-Type", "text/html")
	data := struct {
		Success bool
		Warning bool
		Time    string
	}{
		Success: success,
		Warning: warning,
		Time:    time.Now().Format("2006-01-02 15:04:05"),
	}

	h.tmpl.ExecuteTemplate(w, "audit-status", data)
}

// handleOverview shows audit overview metrics
func (h *AuditHandler) handleOverview(w http.ResponseWriter, r *http.Request) {
	period := r.URL.Query().Get("period")
	if period == "" {
		period = "today"
	}

	var timeConstraint string
	switch period {
	case "week":
		timeConstraint = "AND created_at >= datetime('now', '-7 days')"
	case "month":
		timeConstraint = "AND created_at >= datetime('now', '-30 days')"
	default:
		timeConstraint = "AND created_at >= datetime('now', 'start of day')"
	}

	// Get metrics from database
	rows, err := h.db.Query(`
		SELECT category, severity, COUNT(*) as count
		FROM audit_logs
		WHERE 1=1 `+timeConstraint+`
		GROUP BY category, severity
		ORDER BY category, severity
	`)
	if err != nil {
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	// Process results
	metrics := make(map[string]map[string]int)
	for rows.Next() {
		var category, severity string
		var count int
		if err := rows.Scan(&category, &severity, &count); err != nil {
			continue
		}
		if metrics[category] == nil {
			metrics[category] = make(map[string]int)
		}
		metrics[category][severity] = count
	}

	// Prepare chart data
	data := struct {
		Metrics map[string]map[string]int
		Period  string
	}{
		Metrics: metrics,
		Period:  period,
	}

	h.tmpl.ExecuteTemplate(w, "overview-content", data)
}

// handleIssues shows audit issues
func (h *AuditHandler) handleIssues(w http.ResponseWriter, r *http.Request) {
	severity := r.URL.Query().Get("severity")
	var whereClause string
	if severity != "" && severity != "all" {
		whereClause = fmt.Sprintf("WHERE severity = '%s'", severity)
	}

	// Get issues from database
	rows, err := h.db.Query(`
		SELECT category, severity, message, details, created_at
		FROM audit_logs
		`+whereClause+`
		ORDER BY created_at DESC
		LIMIT 100
	`)
	if err != nil {
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	// Process results
	var issues []struct {
		Category  string
		Severity  string
		Message   string
		Details   string
		CreatedAt time.Time
	}

	for rows.Next() {
		var issue struct {
			Category  string
			Severity  string
			Message   string
			Details   string
			CreatedAt time.Time
		}
		if err := rows.Scan(&issue.Category, &issue.Severity, &issue.Message, &issue.Details, &issue.CreatedAt); err != nil {
			continue
		}
		issues = append(issues, issue)
	}

	h.tmpl.ExecuteTemplate(w, "issues-content", issues)
}

// handleStructure shows project structure analysis
func (h *AuditHandler) handleStructure(w http.ResponseWriter, r *http.Request) {
	// Get directory structure from database
	rows, err := h.db.Query(`
		SELECT d.path, d.type, d.description,
			   COUNT(f.id) as file_count
		FROM directories d
		LEFT JOIN files f ON f.directory_id = d.id
		GROUP BY d.id
		ORDER BY d.path
	`)
	if err != nil {
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	// Build directory tree
	tree := make(map[string]interface{})
	for rows.Next() {
		var path, dirType, description string
		var fileCount int
		if err := rows.Scan(&path, &dirType, &description, &fileCount); err != nil {
			continue
		}

		// Split path into components
		components := filepath.SplitList(path)
		current := tree
		for _, comp := range components {
			if current[comp] == nil {
				current[comp] = make(map[string]interface{})
			}
			current = current[comp].(map[string]interface{})
		}
		current["type"] = dirType
		current["description"] = description
		current["fileCount"] = fileCount
	}

	h.tmpl.ExecuteTemplate(w, "structure-content", tree)
}

// handleQuality shows code quality metrics
func (h *AuditHandler) handleQuality(w http.ResponseWriter, r *http.Request) {
	// Get code metrics from database
	rows, err := h.db.Query(`
		SELECT f.path,
			   m.lines_of_code,
			   m.complexity,
			   m.function_count,
			   m.test_coverage
		FROM files f
		JOIN code_metrics m ON m.file_id = f.id
		WHERE m.complexity > 10 OR m.test_coverage < 70
		ORDER BY m.complexity DESC
	`)
	if err != nil {
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	// Process results
	var files []struct {
		Path         string
		LOC         int
		Complexity  int
		Functions   int
		Coverage    float64
	}

	for rows.Next() {
		var file struct {
			Path         string
			LOC         int
			Complexity  int
			Functions   int
			Coverage    float64
		}
		if err := rows.Scan(&file.Path, &file.LOC, &file.Complexity, &file.Functions, &file.Coverage); err != nil {
			continue
		}
		files = append(files, file)
	}

	h.tmpl.ExecuteTemplate(w, "quality-content", files)
}

// handleUsage shows code usage analysis
func (h *AuditHandler) handleUsage(w http.ResponseWriter, r *http.Request) {
	// Get usage data from database
	rows, err := h.db.Query(`
		SELECT f.path, f.type, f.status,
			   COUNT(d.id) as dependency_count
		FROM files f
		LEFT JOIN dependencies d ON d.source_file_id = f.id
		GROUP BY f.id
		HAVING f.status = 'unused' OR dependency_count = 0
		ORDER BY f.path
	`)
	if err != nil {
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	// Process results
	var files []struct {
		Path            string
		Type            string
		Status          string
		DependencyCount int
	}

	for rows.Next() {
		var file struct {
			Path            string
			Type            string
			Status          string
			DependencyCount int
		}
		if err := rows.Scan(&file.Path, &file.Type, &file.Status, &file.DependencyCount); err != nil {
			continue
		}
		files = append(files, file)
	}

	h.tmpl.ExecuteTemplate(w, "usage-content", files)
}

// handleDocumentation shows documentation status
func (h *AuditHandler) handleDocumentation(w http.ResponseWriter, r *http.Request) {
	// Get documentation status from database
	rows, err := h.db.Query(`
		SELECT f.path,
			   d.has_readme,
			   d.has_tests,
			   d.has_docs,
			   d.last_updated
		FROM files f
		JOIN documentation d ON d.file_id = f.id
		WHERE d.has_readme = 0 OR d.has_tests = 0 OR d.has_docs = 0
		ORDER BY f.path
	`)
	if err != nil {
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	// Process results
	var files []struct {
		Path        string
		HasReadme   bool
		HasTests    bool
		HasDocs     bool
		LastUpdated time.Time
	}

	for rows.Next() {
		var file struct {
			Path        string
			HasReadme   bool
			HasTests    bool
			HasDocs     bool
			LastUpdated time.Time
		}
		if err := rows.Scan(&file.Path, &file.HasReadme, &file.HasTests, &file.HasDocs, &file.LastUpdated); err != nil {
			continue
		}
		files = append(files, file)
	}

	h.tmpl.ExecuteTemplate(w, "documentation-content", files)
}

// handleDependencies shows dependency analysis
func (h *AuditHandler) handleDependencies(w http.ResponseWriter, r *http.Request) {
	// Get dependency data from database
	rows, err := h.db.Query(`
		WITH RECURSIVE
			deps(source, target, depth) AS (
				SELECT source_file_id, target_file_id, 1
				FROM dependencies
				UNION ALL
				SELECT d.source, deps.target, deps.depth + 1
				FROM dependencies d
				JOIN deps ON d.target_file_id = deps.source
				WHERE deps.depth < 5
			)
		SELECT f1.path as source_path,
			   f2.path as target_path,
			   MIN(depth) as min_depth,
			   COUNT(*) as path_count
		FROM deps
		JOIN files f1 ON deps.source = f1.id
		JOIN files f2 ON deps.target = f2.id
		GROUP BY f1.id, f2.id
		ORDER BY path_count DESC
		LIMIT 100
	`)
	if err != nil {
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	// Process results
	var deps []struct {
		SourcePath string
		TargetPath string
		MinDepth   int
		PathCount  int
	}

	for rows.Next() {
		var dep struct {
			SourcePath string
			TargetPath string
			MinDepth   int
			PathCount  int
		}
		if err := rows.Scan(&dep.SourcePath, &dep.TargetPath, &dep.MinDepth, &dep.PathCount); err != nil {
			continue
		}
		deps = append(deps, dep)
	}

	h.tmpl.ExecuteTemplate(w, "dependencies-content", deps)
}

// handleExport exports audit data
func (h *AuditHandler) handleExport(w http.ResponseWriter, r *http.Request) {
	format := r.URL.Query().Get("format")
	if format == "" {
		format = "json"
	}

	// Get all audit data
	rows, err := h.db.Query(`
		SELECT category, severity, message, details, created_at
		FROM audit_logs
		ORDER BY created_at DESC
	`)
	if err != nil {
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	// Process results
	var logs []struct {
		Category  string    `json:"category"`
		Severity  string    `json:"severity"`
		Message   string    `json:"message"`
		Details   string    `json:"details"`
		CreatedAt time.Time `json:"created_at"`
	}

	for rows.Next() {
		var log struct {
			Category  string    `json:"category"`
			Severity  string    `json:"severity"`
			Message   string    `json:"message"`
			Details   string    `json:"details"`
			CreatedAt time.Time `json:"created_at"`
		}
		if err := rows.Scan(&log.Category, &log.Severity, &log.Message, &log.Details, &log.CreatedAt); err != nil {
			continue
		}
		logs = append(logs, log)
	}

	switch format {
	case "json":
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Content-Disposition", "attachment; filename=audit.json")
		json.NewEncoder(w).Encode(logs)
	default:
		http.Error(w, "Unsupported format", http.StatusBadRequest)
	}
} 