package schema

import (
	"fmt"
	"reflect"

	"flow-control/internal/types"
)

// Package schema implements composite type schemas for Flow Control.
//
// Core types used from internal/types:
// - Schema (types.go) - Interface for data type validation
// - Message (message.go) - Used in validation examples
// - Fields (types.go) - Used for structured logging

// ArraySchema implements Schema for array types
type ArraySchema struct {
	elementSchema types.Schema
	version       string
}

// NewArraySchema creates a schema for array validation
func NewArraySchema(elementSchema types.Schema) types.Schema {
	return &ArraySchema{
		elementSchema: elementSchema,
		version:       "1.0",
	}
}

// Validate implements Schema.Validate for arrays
func (s *ArraySchema) Validate(data interface{}) error {
	val := reflect.ValueOf(data)
	if val.Kind() != reflect.Slice && val.Kind() != reflect.Array {
		return fmt.Errorf("expected array, got %T", data)
	}

	for i := 0; i < val.Len(); i++ {
		elem := val.Index(i).Interface()
		if err := s.elementSchema.Validate(elem); err != nil {
			return fmt.Errorf("invalid element at index %d: %w", i, err)
		}
	}
	return nil
}

// GetType implements Schema.GetType
func (s *ArraySchema) GetType() string {
	return fmt.Sprintf("array<%s>", s.elementSchema.GetType())
}

// GetVersion implements Schema.GetVersion
func (s *ArraySchema) GetVersion() string {
	return s.version
}

// ObjectSchema implements Schema for object types
type ObjectSchema struct {
	properties map[string]types.Schema
	required   []string
	version    string
}

// NewObjectSchema creates a schema for object validation
func NewObjectSchema(properties map[string]types.Schema, required []string) types.Schema {
	return &ObjectSchema{
		properties: properties,
		required:   required,
		version:    "1.0",
	}
}

// Validate implements Schema.Validate for objects
func (s *ObjectSchema) Validate(data interface{}) error {
	val := reflect.ValueOf(data)
	if val.Kind() != reflect.Map && val.Kind() != reflect.Struct {
		return fmt.Errorf("expected object, got %T", data)
	}

	// Convert to map if struct
	var m map[string]interface{}
	if val.Kind() == reflect.Struct {
		m = structToMap(val)
	} else {
		m = data.(map[string]interface{})
	}

	// Check required fields
	for _, req := range s.required {
		if _, ok := m[req]; !ok {
			return fmt.Errorf("missing required field: %s", req)
		}
	}

	// Validate each field
	for name, value := range m {
		schema, ok := s.properties[name]
		if !ok {
			continue // Skip unknown fields
		}
		if err := schema.Validate(value); err != nil {
			return fmt.Errorf("invalid field %s: %w", name, err)
		}
	}
	return nil
}

// GetType implements Schema.GetType
func (s *ObjectSchema) GetType() string {
	return "object"
}

// GetVersion implements Schema.GetVersion
func (s *ObjectSchema) GetVersion() string {
	return s.version
}

// Helper function to convert struct to map
func structToMap(val reflect.Value) map[string]interface{} {
	m := make(map[string]interface{})
	typ := val.Type()
	for i := 0; i < val.NumField(); i++ {
		field := typ.Field(i)
		if field.PkgPath != "" { // Skip unexported fields
			continue
		}
		name := field.Tag.Get("json")
		if name == "" {
			name = field.Name
		}
		m[name] = val.Field(i).Interface()
	}
	return m
}
