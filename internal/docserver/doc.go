// Package docserver implements the documentation server for Flow Control.
//
// The docserver package provides a web-based documentation system that includes:
//
// - Package documentation with source code viewing
// - API documentation via Swagger UI
// - Flow language guide and examples
// - Search functionality
// - Hot reloading during development
//
// The documentation server uses HTML templates and Tailwind CSS for styling,
// providing a modern and responsive user interface. It integrates with the
// main server to provide a seamless documentation experience.
//
// Example usage:
//
//	// Create documentation server
//	docServer := docserver.New(logger)
//
//	// Mount documentation routes
//	router.Mount("/docs", docServer.Routes())
//
// The documentation server supports:
//
// - Package listing and documentation
// - Source code viewing with syntax highlighting
// - API documentation with interactive examples
// - Full-text search across all documentation
// - Live updates during development
package docserver
