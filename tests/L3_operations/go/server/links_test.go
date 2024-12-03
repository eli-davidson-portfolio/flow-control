package server_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"flow-control/internal/docserver"
	"flow-control/internal/logger"
	"flow-control/internal/server"
	"flow-control/internal/store"
	"flow-control/internal/types"

	"github.com/stretchr/testify/require"
	"golang.org/x/net/html"
)

// extractLinks extracts all links from an HTML page
func extractLinks(body io.Reader) ([]string, error) {
	links := make([]string, 0)
	z := html.NewTokenizer(body)

	for {
		tt := z.Next()
		switch tt {
		case html.ErrorToken:
			if z.Err() == io.EOF {
				return links, nil
			}
			return links, z.Err()
		case html.StartTagToken, html.SelfClosingTagToken:
			token := z.Token()
			if token.Data == "a" {
				for i := range token.Attr {
					attr := &token.Attr[i]
					if attr.Key == "href" {
						links = append(links, attr.Val)
					}
				}
			}
		}
	}
}

// setupTestTemplates creates test templates for the documentation server
func setupTestTemplates(t *testing.T) string {
	t.Helper()

	templates := map[string]string{
		"base.html":            `{{define "base"}}<!DOCTYPE html><html><body>{{template "content" .}}</body></html>{{end}}`,
		"index.html":           `{{define "content"}}<h1>{{.Title}}</h1>{{range .Packages}}<div><a href="/docs/pkg/{{.Path}}">{{.Name}}</a></div>{{end}}{{end}}`,
		"package_list.html":    `{{define "content"}}<h1>Packages</h1>{{range .Packages}}<div><a href="/docs/pkg/{{.Path}}">{{.Name}}</a></div>{{end}}{{end}}`,
		"package.html":         `{{define "content"}}<h1>Package {{.Title}}</h1>{{range .Files}}<div><a href="/docs/src/{{.Name}}">{{.Name}}</a></div>{{end}}{{end}}`,
		"source_list.html":     `{{define "content"}}<h1>Source Code</h1>{{range .Packages}}<div><a href="/docs/src/{{.Path}}">{{.Name}}</a></div>{{end}}{{end}}`,
		"source.html":          `{{define "content"}}<h1>{{.Title}}</h1><pre>{{.Content}}</pre>{{end}}`,
		"source_dir.html":      `{{define "content"}}<h1>{{.Title}}</h1>{{range .Files}}<div><a href="/docs/src/{{.Path}}/{{.Name}}">{{.Name}}</a></div>{{end}}{{end}}`,
		"search.html":          `{{define "content"}}<h1>Search Results</h1>{{if .Query}}{{range .Results}}<div><a href="{{.URL}}">{{.Title}}</a></div>{{end}}{{end}}{{end}}`,
		"package_content.html": `{{define "content"}}<h1>Package {{.Title}}</h1>{{range .Files}}<div><a href="/docs/src/{{.Name}}">{{.Name}}</a></div>{{end}}{{end}}`,
	}

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

	// Create test package structure
	err = os.MkdirAll(filepath.Join(tmpDir, "internal", "docserver"), 0o755)
	require.NoError(t, err)
	err = os.WriteFile(
		filepath.Join(tmpDir, "internal", "docserver", "doc.go"),
		[]byte("// Package docserver implements the documentation server."),
		0o644,
	)
	require.NoError(t, err)

	return tmpDir
}

func TestLinks(t *testing.T) {
	// Set up test templates
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

	// Create test dependencies
	log := logger.New()
	st, err := store.New("test.db", log)
	require.NoError(t, err)
	defer func() { _ = st.Close() }()

	// Create test server
	srv := server.New(st, log)

	// Mount documentation server
	docs := docserver.New(log)
	srv.Mount("/docs", docs)

	ts := httptest.NewServer(srv)
	defer ts.Close()

	// Create a test flow for API endpoints
	config := map[string]interface{}{
		"retries": 3,
	}
	configJSON, err := json.Marshal(config)
	require.NoError(t, err)

	testFlow := &types.RuntimeFlow{
		ID:     "test-flow",
		Name:   "Test Flow",
		Config: string(configJSON),
	}
	err = st.CreateFlow(testFlow)
	require.NoError(t, err)

	// Define all pages to check
	pages := []struct {
		name string
		path string
	}{
		{"Index", "/"},
		{"Package List", "/docs/pkg"},
		{"Source List", "/docs/src"},
		{"Search", "/docs/search"},
		{"Swagger UI", "/api/swagger/index.html"},
		{"API Docs", "/api/swagger/doc.json"},
	}

	// Visit each page and check its links
	for _, page := range pages {
		t.Run(page.name, func(t *testing.T) {
			resp, err := http.Get(ts.URL + page.path)
			require.NoError(t, err)
			defer func() { _ = resp.Body.Close() }()

			require.Equal(t, http.StatusOK, resp.StatusCode)

			// For JSON endpoints, validate the response
			if strings.HasSuffix(page.path, ".json") {
				var data interface{}
				err = json.NewDecoder(resp.Body).Decode(&data)
				require.NoError(t, err)
				require.NotNil(t, data)
				return
			}

			// For HTML pages, extract and check all links
			links, err := extractLinks(resp.Body)
			require.NoError(t, err)

			// Visit each link
			for _, link := range links {
				// Skip external links and anchors
				if strings.HasPrefix(link, "http") || strings.HasPrefix(link, "#") {
					continue
				}

				t.Run(link, func(t *testing.T) {
					linkResp, err := http.Get(ts.URL + link)
					require.NoError(t, err)
					defer func() { _ = linkResp.Body.Close() }()

					require.Equal(t, http.StatusOK, linkResp.StatusCode,
						"Link %s returned status %d", link, linkResp.StatusCode)
				})
			}
		})
	}

	// Test API endpoints
	t.Run("API Endpoints", func(t *testing.T) {
		endpoints := []struct {
			name   string
			method string
			path   string
			body   string
		}{
			{"List Flows", "GET", "/api/flows", ""},
			{"Get Flow", "GET", "/api/flows/test-flow", ""},
			{"Create Flow", "POST", "/api/flows", `{"id":"new-flow","name":"new-flow","config":"{\"retries\":3}"}`},
			{"Update Flow", "PUT", "/api/flows/test-flow", `{"id":"test-flow","name":"updated-flow","config":"{\"retries\":5}"}`},
			{"Delete Flow", "DELETE", "/api/flows/test-flow", ""},
		}

		for _, e := range endpoints {
			t.Run(e.name, func(t *testing.T) {
				var req *http.Request
				var err error

				if e.body != "" {
					req, err = http.NewRequest(e.method, ts.URL+e.path, strings.NewReader(e.body))
				} else {
					req, err = http.NewRequest(e.method, ts.URL+e.path, http.NoBody)
				}
				require.NoError(t, err)

				if e.body != "" {
					req.Header.Set("Content-Type", "application/json")
				}

				resp, err := http.DefaultClient.Do(req)
				require.NoError(t, err)
				defer func() { _ = resp.Body.Close() }()

				// All endpoints should return success status codes (2xx)
				require.GreaterOrEqual(t, resp.StatusCode, 200)
				require.Less(t, resp.StatusCode, 300)

				// For GET requests, validate JSON response
				if e.method == "GET" && resp.StatusCode == http.StatusOK {
					var data interface{}
					err = json.NewDecoder(resp.Body).Decode(&data)
					require.NoError(t, err)
					require.NotNil(t, data)
				}
			})
		}
	})
}
