package docserver

import (
	"fmt"
	"html/template"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"flow-control/internal/types"

	"github.com/go-chi/chi/v5"
)

// Server represents the documentation server
type Server struct {
	router    chi.Router
	log       types.Logger
	templates *template.Template
	rootDir   string
}

// PackageInfo represents information about a package
type PackageInfo struct {
	Name        string
	Path        string
	Description string
}

// New creates a new documentation server
func New(log types.Logger) *Server {
	s := &Server{
		router:  chi.NewRouter(),
		log:     log,
		rootDir: ".",
	}

	// Parse templates
	var err error
	s.templates, err = template.ParseGlob("internal/docserver/templates/*.html")
	if err != nil {
		log.Error("Failed to parse templates", err, types.Fields{
			"component": "docserver",
		})
		os.Exit(1)
	}

	s.setupRoutes()
	return s
}

// Routes returns the router for mounting
func (s *Server) Routes() chi.Router {
	return s.router
}

// setupRoutes configures the documentation server routes
func (s *Server) setupRoutes() {
	s.router.Get("/", s.handleIndex)
	s.router.Get("/pkg", s.handlePackageList)
	s.router.Get("/pkg/*", s.handlePackage)
	s.router.Get("/src", s.handleSourceList)
	s.router.Get("/src/*", s.handleSource)
	s.router.Get("/search", s.handleSearch)
}

// handleIndex serves the documentation index page
func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	s.log.Debug("Serving documentation index", types.Fields{
		"component": "docserver",
		"handler":   "handleIndex",
	})

	packages, err := s.listPackages()
	if err != nil {
		s.log.Error("Failed to list packages", err, types.Fields{
			"component": "docserver",
			"handler":   "handleIndex",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	data := map[string]interface{}{
		"Title":    "Flow Control Documentation",
		"Packages": packages,
	}

	if err := s.templates.ExecuteTemplate(w, "base.html", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handleIndex",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// handlePackage serves package documentation
func (s *Server) handlePackage(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/pkg/")
	s.log.Debug("Serving package documentation", types.Fields{
		"component": "docserver",
		"handler":   "handlePackage",
		"path":      path,
	})

	// Construct the full package path
	pkgPath := filepath.Join("internal", path)
	files, err := os.ReadDir(pkgPath)
	if err != nil {
		s.log.Error("Failed to read package directory", err, types.Fields{
			"component": "docserver",
			"handler":   "handlePackage",
			"path":      pkgPath,
		})
		http.Error(w, "Package not found", http.StatusNotFound)
		return
	}

	// Get package description from doc.go if it exists
	var description string
	docFile := filepath.Join(pkgPath, "doc.go")
	if content, err := os.ReadFile(docFile); err == nil {
		description = strings.TrimSpace(string(content))
	}

	// Get list of Go files
	var goFiles []string
	for _, file := range files {
		if !file.IsDir() && strings.HasSuffix(file.Name(), ".go") {
			goFiles = append(goFiles, file.Name())
		}
	}

	data := map[string]interface{}{
		"Title":       path,
		"Files":       goFiles,
		"Description": description,
		"Path":        path,
	}

	if err := s.templates.ExecuteTemplate(w, "package.html", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handlePackage",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// handleSource serves source code files
func (s *Server) handleSource(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/src/")
	s.log.Debug("Serving source code", types.Fields{
		"component": "docserver",
		"handler":   "handleSource",
		"path":      path,
	})

	// Construct the full file path
	filePath := filepath.Join("internal", path)
	content, err := os.ReadFile(filePath)
	if err != nil {
		s.log.Error("Failed to read source file", err, types.Fields{
			"component": "docserver",
			"handler":   "handleSource",
			"path":      filePath,
		})
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}

	data := map[string]interface{}{
		"Title":   filepath.Base(path),
		"Content": string(content),
		"Path":    path,
	}

	if err := s.templates.ExecuteTemplate(w, "source.html", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handleSource",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// handleSearch handles documentation search
func (s *Server) handleSearch(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	s.log.Debug("Searching documentation", types.Fields{
		"component": "docserver",
		"handler":   "handleSearch",
		"query":     query,
	})

	data := map[string]interface{}{
		"Title": "Search Results",
		"Query": query,
	}

	if err := s.templates.ExecuteTemplate(w, "base.html", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handleSearch",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// handlePackageList serves the package list page
func (s *Server) handlePackageList(w http.ResponseWriter, r *http.Request) {
	s.log.Debug("Serving package list", types.Fields{
		"component": "docserver",
		"handler":   "handlePackageList",
	})

	packages, err := s.listPackages()
	if err != nil {
		s.log.Error("Failed to list packages", err, types.Fields{
			"component": "docserver",
			"handler":   "handlePackageList",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	data := map[string]interface{}{
		"Title":    "Packages",
		"Packages": packages,
	}

	if err := s.templates.ExecuteTemplate(w, "package_list.html", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handlePackageList",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// handleSourceList serves the source list page
func (s *Server) handleSourceList(w http.ResponseWriter, r *http.Request) {
	s.log.Debug("Serving source list", types.Fields{
		"component": "docserver",
		"handler":   "handleSourceList",
	})

	packages, err := s.listPackages()
	if err != nil {
		s.log.Error("Failed to list packages", err, types.Fields{
			"component": "docserver",
			"handler":   "handleSourceList",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	data := map[string]interface{}{
		"Title":    "Source Code",
		"Packages": packages,
	}

	if err := s.templates.ExecuteTemplate(w, "source_list.html", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handleSourceList",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// listPackages returns a list of all packages in the project
func (s *Server) listPackages() ([]PackageInfo, error) {
	var packages []PackageInfo

	err := filepath.Walk("internal", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() && path != "internal" {
			pkg := PackageInfo{
				Name: filepath.Base(path),
				Path: strings.TrimPrefix(path, "internal/"),
			}

			// Try to read package description from doc.go if it exists
			docFile := filepath.Join(path, "doc.go")
			if content, err := os.ReadFile(docFile); err == nil {
				pkg.Description = strings.TrimSpace(string(content))
			}

			packages = append(packages, pkg)
		}

		return nil
	})

	if err != nil {
		return nil, fmt.Errorf("failed to walk directory: %w", err)
	}

	// Sort packages by name
	sort.Slice(packages, func(i, j int) bool {
		return packages[i].Name < packages[j].Name
	})

	return packages, nil
}
