package schema

import (
	"fmt"
	"time"

	"flow-control/internal/types"
)

// Package schema implements type validation and schema management for Flow Control.
// It provides basic and composite schema types, along with a registry for managing
// schema versions and compatibility.

// Core types used from internal/types:
// - Schema (types.go) - Interface for data type validation
// - Message (message.go) - Used in validation examples
// - Fields (types.go) - Used for structured logging

// BasicSchema implements the Schema interface for primitive types
type BasicSchema struct {
	schemaType string
	version    string
	validator  func(interface{}) error
}

// NewStringSchema creates a schema for string validation
func NewStringSchema() types.Schema {
	return &BasicSchema{
		schemaType: "string",
		version:    "1.0",
		validator: func(data interface{}) error {
			if _, ok := data.(string); !ok {
				return fmt.Errorf("expected string, got %T", data)
			}
			return nil
		},
	}
}

// NewIntSchema creates a schema for integer validation
func NewIntSchema() types.Schema {
	return &BasicSchema{
		schemaType: "int",
		version:    "1.0",
		validator: func(data interface{}) error {
			switch data.(type) {
			case int, int8, int16, int32, int64:
				return nil
			default:
				return fmt.Errorf("expected integer, got %T", data)
			}
		},
	}
}

// NewFloatSchema creates a schema for float validation
func NewFloatSchema() types.Schema {
	return &BasicSchema{
		schemaType: "float",
		version:    "1.0",
		validator: func(data interface{}) error {
			switch data.(type) {
			case float32, float64:
				return nil
			default:
				return fmt.Errorf("expected float, got %T", data)
			}
		},
	}
}

// NewBoolSchema creates a schema for boolean validation
func NewBoolSchema() types.Schema {
	return &BasicSchema{
		schemaType: "bool",
		version:    "1.0",
		validator: func(data interface{}) error {
			if _, ok := data.(bool); !ok {
				return fmt.Errorf("expected bool, got %T", data)
			}
			return nil
		},
	}
}

// NewTimeSchema creates a schema for time.Time validation
func NewTimeSchema() types.Schema {
	return &BasicSchema{
		schemaType: "time",
		version:    "1.0",
		validator: func(data interface{}) error {
			if _, ok := data.(time.Time); !ok {
				return fmt.Errorf("expected time.Time, got %T", data)
			}
			return nil
		},
	}
}

// NewAnySchema creates a schema that accepts any type
func NewAnySchema() types.Schema {
	return &BasicSchema{
		schemaType: "any",
		version:    "1.0",
		validator:  func(data interface{}) error { return nil },
	}
}

// Validate implements Schema.Validate
func (s *BasicSchema) Validate(data interface{}) error {
	if data == nil {
		return fmt.Errorf("cannot validate nil data")
	}
	return s.validator(data)
}

// GetType implements Schema.GetType
func (s *BasicSchema) GetType() string {
	return s.schemaType
}

// GetVersion implements Schema.GetVersion
func (s *BasicSchema) GetVersion() string {
	return s.version
}

// IsCompatible checks if two schemas are compatible
func IsCompatible(s1, s2 types.Schema) bool {
	if s1.GetType() != s2.GetType() {
		return false
	}
	// For now, we only check major version compatibility
	v1 := s1.GetVersion()
	v2 := s2.GetVersion()
	return v1[0] == v2[0] // Compare major version
}
