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
	templates map[string]*template.Template
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
	// Get the absolute path to the workspace root
	rootDir, err := os.Getwd()
	if err != nil {
		log.Error("Failed to get working directory", err, types.Fields{
			"component": "docserver",
		})
		os.Exit(1)
	}

	s := &Server{
		router:    chi.NewRouter(),
		log:       log,
		rootDir:   rootDir,
		templates: make(map[string]*template.Template),
	}

	// Parse templates
	templatePath := filepath.Join(rootDir, "internal", "docserver", "templates")
	s.log.Debug("Loading templates from", types.Fields{
		"component": "docserver",
		"path":      templatePath,
	})

	// List of template files
	templateFiles := []string{
		"index.html",
		"package_list.html",
		"package.html",
		"source_list.html",
		"source.html",
		"source_dir.html",
		"search.html",
		"package_content.html",
	}

	// Parse each template with base.html
	for _, tmpl := range templateFiles {
		t, err := template.ParseFiles(
			filepath.Join(templatePath, "base.html"),
			filepath.Join(templatePath, tmpl),
		)
		if err != nil {
			log.Error("Failed to parse template", err, types.Fields{
				"component": "docserver",
				"template":  tmpl,
			})
			os.Exit(1)
		}
		s.templates[tmpl] = t
		s.log.Debug("Loaded template", types.Fields{
			"component": "docserver",
			"template":  tmpl,
		})
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
	s.router.Get("/docs", s.handleIndex)
	s.router.Get("/docs/", s.handleIndex)
	s.router.Get("/pkg", s.handlePackageList)
	s.router.Get("/docs/pkg", s.handlePackageList)
	s.router.Get("/pkg/*", s.handlePackage)
	s.router.Get("/docs/pkg/*", s.handlePackage)
	s.router.Get("/src", s.handleSourceList)
	s.router.Get("/docs/src", s.handleSourceList)
	s.router.Get("/src/*", s.handleSource)
	s.router.Get("/docs/src/*", s.handleSource)
	s.router.Get("/search", s.handleSearch)
	s.router.Get("/docs/search", s.handleSearch)
}

// handleIndex serves the documentation index page
func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
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

	tmpl := s.templates["index.html"]
	if tmpl == nil {
		s.log.Error("Template not found", fmt.Errorf("index.html not loaded"), types.Fields{
			"component": "docserver",
			"handler":   "handleIndex",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	if err := tmpl.ExecuteTemplate(w, "base", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handleIndex",
			"template":  "index.html",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// handlePackage serves package documentation
func (s *Server) handlePackage(w http.ResponseWriter, r *http.Request) {
	// Remove /pkg/ prefix and handle both with and without trailing slash
	path := strings.TrimPrefix(strings.TrimPrefix(r.URL.Path, "/pkg/"), "/")
	s.log.Debug("Processing package path", types.Fields{
		"component": "docserver",
		"path":      path,
	})

	// Construct the full package path relative to workspace root
	pkgPath := filepath.Join("internal", path)
	s.log.Debug("Looking for package in", types.Fields{
		"component": "docserver",
		"pkg_path":  pkgPath,
	})

	// Check if the directory exists
	if _, err := os.Stat(pkgPath); os.IsNotExist(err) {
		// Try without the docs/pkg prefix
		pkgPath = filepath.Join("internal", strings.TrimPrefix(path, "docs/pkg/"))
		if _, err := os.Stat(pkgPath); os.IsNotExist(err) {
			s.log.Error("Package directory not found", err, types.Fields{
				"component": "docserver",
				"path":      pkgPath,
			})
			http.Error(w, "Package not found", http.StatusNotFound)
			return
		}
	}

	// Get package description from doc.go if it exists
	var description string
	docFile := filepath.Join(pkgPath, "doc.go")
	if content, err := os.ReadFile(docFile); err == nil {
		description = string(content)
	}

	// Get list of Go files and their contents
	files, err := os.ReadDir(pkgPath)
	if err != nil {
		s.log.Error("Failed to read package directory", err, types.Fields{
			"component": "docserver",
			"path":      pkgPath,
		})
		http.Error(w, "Failed to read package", http.StatusInternalServerError)
		return
	}

	var goFiles []map[string]interface{}
	for _, file := range files {
		if !file.IsDir() && strings.HasSuffix(file.Name(), ".go") {
			filePath := filepath.Join(pkgPath, file.Name())
			content, err := os.ReadFile(filePath)
			if err != nil {
				s.log.Error("Failed to read file", err, types.Fields{
					"component": "docserver",
					"file":      filePath,
				})
				continue
			}
			goFiles = append(goFiles, map[string]interface{}{
				"Name":    file.Name(),
				"Content": string(content),
			})
		}
	}

	data := map[string]interface{}{
		"Title":       path,
		"Path":        path,
		"Description": description,
		"Files":       goFiles,
	}

	tmpl := s.templates["package.html"]
	if tmpl == nil {
		s.log.Error("Template not found", fmt.Errorf("package.html not loaded"), types.Fields{
			"component": "docserver",
			"handler":   "handlePackage",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	if err := tmpl.ExecuteTemplate(w, "base", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handlePackage",
			"template":  "package.html",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// handleSource serves source code files
func (s *Server) handleSource(w http.ResponseWriter, r *http.Request) {
	// Remove /src/ prefix and handle both with and without trailing slash
	path := strings.TrimPrefix(strings.TrimPrefix(r.URL.Path, "/src/"), "/")
	s.log.Debug("Processing source path", types.Fields{
		"component": "docserver",
		"path":      path,
	})

	// Construct the full file path relative to workspace root
	filePath := path
	if !strings.HasPrefix(path, "internal/") {
		filePath = filepath.Join("internal", strings.TrimPrefix(path, "docs/src/"))
	}

	s.log.Debug("Looking for source file", types.Fields{
		"component": "docserver",
		"file_path": filePath,
	})

	// Check if it's a directory
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		s.log.Error("Source not found", err, types.Fields{
			"component": "docserver",
			"path":      filePath,
		})
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}

	if fileInfo.IsDir() {
		// List directory contents
		files, err := os.ReadDir(filePath)
		if err != nil {
			s.log.Error("Failed to read directory", err, types.Fields{
				"component": "docserver",
				"path":      filePath,
			})
			http.Error(w, "Failed to read directory", http.StatusInternalServerError)
			return
		}

		var fileList []map[string]interface{}
		for _, file := range files {
			if !strings.HasPrefix(file.Name(), ".") { // Skip hidden files
				fileList = append(fileList, map[string]interface{}{
					"Name": file.Name(),
					"Path": filepath.Join(path, file.Name()),
				})
			}
		}

		data := map[string]interface{}{
			"Title": path,
			"Path":  path,
			"Files": fileList,
		}

		tmpl := s.templates["source_dir.html"]
		if tmpl == nil {
			s.log.Error("Template not found", fmt.Errorf("source_dir.html not loaded"), types.Fields{
				"component": "docserver",
				"handler":   "handleSource",
			})
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}

		if err := tmpl.ExecuteTemplate(w, "base", data); err != nil {
			s.log.Error("Failed to render template", err, types.Fields{
				"component": "docserver",
				"handler":   "handleSource",
				"template":  "source_dir.html",
			})
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		}
		return
	}

	// Read file contents
	content, err := os.ReadFile(filePath)
	if err != nil {
		s.log.Error("Failed to read file", err, types.Fields{
			"component": "docserver",
			"file":      filePath,
		})
		http.Error(w, "Failed to read file", http.StatusInternalServerError)
		return
	}

	data := map[string]interface{}{
		"Title":   filepath.Base(path),
		"Path":    path,
		"Content": string(content),
	}

	tmpl := s.templates["source.html"]
	if tmpl == nil {
		s.log.Error("Template not found", fmt.Errorf("source.html not loaded"), types.Fields{
			"component": "docserver",
			"handler":   "handleSource",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	if err := tmpl.ExecuteTemplate(w, "base", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handleSource",
			"template":  "source.html",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// handleSearch serves the search page
func (s *Server) handleSearch(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	data := map[string]interface{}{
		"Title": "Search Documentation",
		"Query": query,
	}

	if query != "" {
		// Perform search
		results, err := s.searchPackages(query)
		if err != nil {
			s.log.Error("Failed to search packages", err, types.Fields{
				"component": "docserver",
				"handler":   "handleSearch",
				"query":     query,
			})
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
		data["Results"] = results
	}

	tmpl := s.templates["search.html"]
	if tmpl == nil {
		s.log.Error("Template not found", fmt.Errorf("search.html not loaded"), types.Fields{
			"component": "docserver",
			"handler":   "handleSearch",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	if err := tmpl.ExecuteTemplate(w, "base", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handleSearch",
			"template":  "search.html",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// SearchResult represents a search result
type SearchResult struct {
	Title       string
	Description string
	URL         string
	Path        string
}

// searchPackages searches for packages matching the query
func (s *Server) searchPackages(query string) ([]SearchResult, error) {
	packages, err := s.listPackages()
	if err != nil {
		return nil, err
	}

	var results []SearchResult
	for i := range packages {
		pkg := &packages[i]
		if strings.Contains(strings.ToLower(pkg.Name), strings.ToLower(query)) ||
			strings.Contains(strings.ToLower(pkg.Description), strings.ToLower(query)) {
			results = append(results, SearchResult{
				Title:       pkg.Name,
				Description: pkg.Description,
				URL:         fmt.Sprintf("/docs/pkg/%s", pkg.Path),
				Path:        pkg.Path,
			})
		}
	}

	return results, nil
}

// handlePackageList serves the package list page
func (s *Server) handlePackageList(w http.ResponseWriter, r *http.Request) {
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

	tmpl := s.templates["package_list.html"]
	if tmpl == nil {
		s.log.Error("Template not found", fmt.Errorf("package_list.html not loaded"), types.Fields{
			"component": "docserver",
			"handler":   "handlePackageList",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	if err := tmpl.ExecuteTemplate(w, "base", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handlePackageList",
			"template":  "package_list.html",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// handleSourceList serves the source code list page
func (s *Server) handleSourceList(w http.ResponseWriter, r *http.Request) {
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

	tmpl := s.templates["source_list.html"]
	if tmpl == nil {
		s.log.Error("Template not found", fmt.Errorf("source_list.html not loaded"), types.Fields{
			"component": "docserver",
			"handler":   "handleSourceList",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	if err := tmpl.ExecuteTemplate(w, "base", data); err != nil {
		s.log.Error("Failed to render template", err, types.Fields{
			"component": "docserver",
			"handler":   "handleSourceList",
			"template":  "source_list.html",
		})
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// listPackages returns a list of all packages in the codebase
func (s *Server) listPackages() ([]PackageInfo, error) {
	var packages []PackageInfo

	// Get list of packages in internal directory
	internalPath := filepath.Join(s.rootDir, "internal")
	entries, err := os.ReadDir(internalPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read internal directory: %w", err)
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		pkgPath := filepath.Join(internalPath, entry.Name())
		docFile := filepath.Join(pkgPath, "doc.go")

		var description string
		if content, err := os.ReadFile(docFile); err == nil {
			description = string(content)
		}

		packages = append(packages, PackageInfo{
			Name:        entry.Name(),
			Path:        entry.Name(),
			Description: description,
		})
	}

	// Sort packages by name
	sort.Slice(packages, func(i, j int) bool {
		return packages[i].Name < packages[j].Name
	})

	return packages, nil
}

// ServeHTTP implements the http.Handler interface
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.router.ServeHTTP(w, r)
}
