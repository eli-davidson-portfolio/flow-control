package server_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"flow-control/internal/logger"
	"flow-control/internal/server"
	"flow-control/internal/store"

	"github.com/stretchr/testify/require"
)

func TestSwaggerEndpoint(t *testing.T) {
	// Create test dependencies
	log := logger.New()
	st := &store.Store{} // Empty store is fine for this test

	// Create a test server
	srv := server.New(st, log)
	ts := httptest.NewServer(srv)
	defer ts.Close()

	// Test that swagger UI is accessible
	resp, err := http.Get(ts.URL + "/api/swagger/index.html")
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	// Test that swagger spec is accessible
	resp, err = http.Get(ts.URL + "/api/swagger/doc.json")
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)
}
