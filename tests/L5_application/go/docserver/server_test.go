package docserver_test

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"flow-control/internal/docserver"
	"flow-control/internal/logger"

	"github.com/stretchr/testify/require"
)

var templates = map[string]string{
	"base.html":            `{{define "base"}}<!DOCTYPE html><html><body>{{template "content" .}}</body></html>{{end}}`,
	"index.html":           `{{define "content"}}<h1>{{.Title}}</h1>{{range .Packages}}<div>{{.Name}}</div>{{end}}{{end}}`,
	"package_list.html":    `{{define "content"}}<h1>Packages</h1>{{range .Packages}}<div>{{.Name}}</div>{{end}}{{end}}`,
	"package.html":         `{{define "content"}}<h1>Package {{.Title}}</h1>{{range .Files}}<div>{{.Name}}</div>{{end}}{{end}}`,
	"source_list.html":     `{{define "content"}}<h1>Source Code</h1>{{range .Packages}}<div>{{.Name}}</div>{{end}}{{end}}`,
	"source.html":          `{{define "content"}}<h1>{{.Title}}</h1><pre>{{.Content}}</pre>{{end}}`,
	"source_dir.html":      `{{define "content"}}<h1>{{.Title}}</h1>{{range .Files}}<div>{{.Name}}</div>{{end}}{{end}}`,
	"search.html":          `{{define "content"}}<h1>Search Results</h1>{{if .Query}}{{range .Results}}<div>{{.Title}}</div>{{end}}{{end}}{{end}}`,
	"package_content.html": `{{define "content"}}<h1>Package {{.Title}}</h1>{{range .Files}}<div>{{.Name}}</div>{{end}}{{end}}`,
}

func setupTestTemplates(t *testing.T) string {
	t.Helper()

	// Create a temporary directory for test templates
	tmpDir, err := os.MkdirTemp("", "docserver-test")
	require.NoError(t, err)

	// Create templates directory
	templatesDir := filepath.Join(tmpDir, "internal", "docserver", "templates")
	err = os.MkdirAll(templatesDir, 0o755)
	require.NoError(t, err)

	// Create test templates
	for name, content := range templates {
		err = os.WriteFile(filepath.Join(templatesDir, name), []byte(content), 0o644)
		require.NoError(t, err)
	}

	return tmpDir
}

func TestTemplateRendering(t *testing.T) {
	// Setup test templates
	tmpDir := setupTestTemplates(t)
	defer func() {
		if err := os.RemoveAll(tmpDir); err != nil {
			t.Errorf("Failed to remove temp dir: %v", err)
		}
	}()

	// Change to the temp directory for the test
	originalWd, err := os.Getwd()
	require.NoError(t, err)
	err = os.Chdir(tmpDir)
	require.NoError(t, err)
	defer func() {
		if err := os.Chdir(originalWd); err != nil {
			t.Errorf("Failed to change back to original directory: %v", err)
		}
	}()

	// Create test package structure
	err = os.MkdirAll(filepath.Join(tmpDir, "internal", "docserver"), 0o755)
	require.NoError(t, err)
	err = os.WriteFile(
		filepath.Join(tmpDir, "internal", "docserver", "doc.go"),
		[]byte("// Package docserver implements the documentation server."),
		0o644,
	)
	require.NoError(t, err)

	log := logger.New()
	server := docserver.New(log)

	tests := []struct {
		name           string
		path           string
		expectedStatus int
		expectedBody   []string
	}{
		{
			name:           "Index Page",
			path:           "/",
			expectedStatus: http.StatusOK,
			expectedBody: []string{
				"Flow Control Documentation",
			},
		},
		{
			name:           "Package List",
			path:           "/pkg",
			expectedStatus: http.StatusOK,
			expectedBody: []string{
				"Packages",
			},
		},
		{
			name:           "Package Documentation",
			path:           "/pkg/docserver",
			expectedStatus: http.StatusOK,
			expectedBody: []string{
				"Package docserver",
			},
		},
		{
			name:           "Source List",
			path:           "/src",
			expectedStatus: http.StatusOK,
			expectedBody: []string{
				"Source Code",
			},
		},
		{
			name:           "Search Page",
			path:           "/search?q=flow",
			expectedStatus: http.StatusOK,
			expectedBody: []string{
				"Search Results",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", tt.path, http.NoBody)
			w := httptest.NewRecorder()

			server.Routes().ServeHTTP(w, req)

			resp := w.Result()
			defer func() {
				if err := resp.Body.Close(); err != nil {
					t.Errorf("Failed to close response body: %v", err)
				}
			}()

			require.Equal(t, tt.expectedStatus, resp.StatusCode)

			body := w.Body.String()
			for _, expected := range tt.expectedBody {
				require.True(t, strings.Contains(body, expected),
					"Expected response to contain '%s', but it didn't.\nGot: %s",
					expected, body)
			}
		})
	}
}
