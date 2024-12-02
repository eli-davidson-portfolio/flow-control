package schema

import (
	"fmt"
	"sync"

	"flow-control/internal/types"
)

// Package schema implements schema type registry for Flow Control.
//
// Core types used from internal/types:
// - Schema (types.go) - Interface for data type validation
// - Message (message.go) - Used in validation examples
// - Fields (types.go) - Used for structured logging

// SchemaRegistry manages schema types and versions
type SchemaRegistry struct {
	schemas map[string]map[string]types.Schema // type -> version -> schema
	mu      sync.RWMutex
}

// NewRegistry creates a new schema registry
func NewRegistry() *SchemaRegistry {
	r := &SchemaRegistry{
		schemas: make(map[string]map[string]types.Schema),
	}
	r.registerBuiltins()
	return r
}

// Register adds a schema to the registry
func (r *SchemaRegistry) Register(schema types.Schema) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	schemaType := schema.GetType()
	version := schema.GetVersion()

	// Initialize version map if needed
	if _, ok := r.schemas[schemaType]; !ok {
		r.schemas[schemaType] = make(map[string]types.Schema)
	}

	// Check for existing schema
	if _, ok := r.schemas[schemaType][version]; ok {
		return fmt.Errorf("schema %s version %s already exists", schemaType, version)
	}

	r.schemas[schemaType][version] = schema
	return nil
}

// Get retrieves a schema from the registry
func (r *SchemaRegistry) Get(schemaType, version string) (types.Schema, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	versions, ok := r.schemas[schemaType]
	if !ok {
		return nil, fmt.Errorf("unknown schema type: %s", schemaType)
	}

	schema, ok := versions[version]
	if !ok {
		return nil, fmt.Errorf("unknown version %s for schema type %s", version, schemaType)
	}

	return schema, nil
}

// GetLatest retrieves the latest version of a schema
func (r *SchemaRegistry) GetLatest(schemaType string) (types.Schema, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	versions, ok := r.schemas[schemaType]
	if !ok {
		return nil, fmt.Errorf("unknown schema type: %s", schemaType)
	}

	var latestVersion string
	for version := range versions {
		if latestVersion == "" || version > latestVersion {
			latestVersion = version
		}
	}

	return versions[latestVersion], nil
}

// ListTypes returns all registered schema types
func (r *SchemaRegistry) ListTypes() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()

	schemaTypes := make([]string, 0, len(r.schemas))
	for t := range r.schemas {
		schemaTypes = append(schemaTypes, t)
	}
	return schemaTypes
}

// ListVersions returns all versions for a schema type
func (r *SchemaRegistry) ListVersions(schemaType string) ([]string, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	versions, ok := r.schemas[schemaType]
	if !ok {
		return nil, fmt.Errorf("unknown schema type: %s", schemaType)
	}

	result := make([]string, 0, len(versions))
	for v := range versions {
		result = append(result, v)
	}
	return result, nil
}

// registerBuiltins registers built-in schema types
func (r *SchemaRegistry) registerBuiltins() {
	builtins := []types.Schema{
		NewStringSchema(),
		NewIntSchema(),
		NewFloatSchema(),
		NewBoolSchema(),
		NewTimeSchema(),
		NewAnySchema(),
	}

	for _, schema := range builtins {
		if err := r.Register(schema); err != nil {
			panic(fmt.Sprintf("failed to register builtin schema: %v", err))
		}
	}
}
