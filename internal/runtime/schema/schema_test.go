package schema_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"flow-control/internal/runtime/schema"
	"flow-control/internal/types"
)

// Package schema_test contains tests for the schema package.
//
// Core types used from internal/types:
// - Schema (types.go) - Interface for data type validation
// - Message (message.go) - Used in test examples

func TestBasicSchemas(t *testing.T) {
	tests := []struct {
		name       string
		schema     types.Schema
		valid      []interface{}
		invalid    []interface{}
		schemaType string
	}{
		{
			name:   "string schema",
			schema: schema.NewStringSchema(),
			valid: []interface{}{
				"hello",
				"",
				"123",
			},
			invalid: []interface{}{
				123,
				true,
				[]string{"hello"},
			},
			schemaType: "string",
		},
		{
			name:   "int schema",
			schema: schema.NewIntSchema(),
			valid: []interface{}{
				42,
				int8(8),
				int16(16),
				int32(32),
				int64(64),
			},
			invalid: []interface{}{
				"123",
				3.14,
				true,
			},
			schemaType: "int",
		},
		{
			name:   "float schema",
			schema: schema.NewFloatSchema(),
			valid: []interface{}{
				3.14,
				float32(3.14),
				float64(3.14),
			},
			invalid: []interface{}{
				"3.14",
				42,
				true,
			},
			schemaType: "float",
		},
		{
			name:   "bool schema",
			schema: schema.NewBoolSchema(),
			valid: []interface{}{
				true,
				false,
			},
			invalid: []interface{}{
				"true",
				1,
				0,
			},
			schemaType: "bool",
		},
		{
			name:   "time schema",
			schema: schema.NewTimeSchema(),
			valid: []interface{}{
				time.Now(),
				time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC),
			},
			invalid: []interface{}{
				"2024-01-01",
				123456789,
				map[string]interface{}{},
			},
			schemaType: "time",
		},
		{
			name:   "any schema",
			schema: schema.NewAnySchema(),
			valid: []interface{}{
				"hello",
				123,
				true,
				3.14,
				time.Now(),
				[]string{"hello"},
				map[string]interface{}{},
			},
			invalid:    []interface{}{},
			schemaType: "any",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Test type
			require.Equal(t, tt.schemaType, tt.schema.GetType())

			// Test version
			require.Equal(t, "1.0", tt.schema.GetVersion())

			// Test valid values
			for _, v := range tt.valid {
				err := tt.schema.Validate(v)
				require.NoError(t, err, "expected %v to be valid", v)
			}

			// Test invalid values
			for _, v := range tt.invalid {
				err := tt.schema.Validate(v)
				require.Error(t, err, "expected %v to be invalid", v)
			}

			// Test nil
			err := tt.schema.Validate(nil)
			require.Error(t, err, "expected nil to be invalid")
		})
	}
}

func TestArraySchema(t *testing.T) {
	stringArray := schema.NewArraySchema(schema.NewStringSchema())

	// Test valid array
	err := stringArray.Validate([]string{"hello", "world"})
	require.NoError(t, err)

	// Test invalid element type
	err = stringArray.Validate([]int{1, 2, 3})
	require.Error(t, err)

	// Test non-array
	err = stringArray.Validate("not an array")
	require.Error(t, err)

	// Test empty array
	err = stringArray.Validate([]string{})
	require.NoError(t, err)

	// Test array type string
	require.Equal(t, "array<string>", stringArray.GetType())
}

func TestObjectSchema(t *testing.T) {
	// Create person schema
	personSchema := schema.NewObjectSchema(
		map[string]types.Schema{
			"name":  schema.NewStringSchema(),
			"age":   schema.NewIntSchema(),
			"email": schema.NewStringSchema(),
		},
		[]string{"name", "age"}, // Required fields
	)

	// Test valid object
	validPerson := map[string]interface{}{
		"name":  "John Doe",
		"age":   30,
		"email": "john@example.com",
	}
	err := personSchema.Validate(validPerson)
	require.NoError(t, err)

	// Test missing required field
	invalidPerson := map[string]interface{}{
		"name": "John Doe",
		// Missing age
	}
	err = personSchema.Validate(invalidPerson)
	require.Error(t, err)

	// Test invalid field type
	invalidPerson = map[string]interface{}{
		"name": "John Doe",
		"age":  "thirty", // Should be int
	}
	err = personSchema.Validate(invalidPerson)
	require.Error(t, err)

	// Test extra field (should be allowed)
	personWithExtra := map[string]interface{}{
		"name":     "John Doe",
		"age":      30,
		"nickname": "Johnny",
	}
	err = personSchema.Validate(personWithExtra)
	require.NoError(t, err)
}

func TestSchemaRegistry(t *testing.T) {
	registry := schema.NewRegistry()

	// Test builtin schemas
	builtinTypes := []string{"string", "int", "float", "bool", "time", "any"}
	for _, typ := range builtinTypes {
		schemaObj, err := registry.GetLatest(typ)
		require.NoError(t, err)
		require.NotNil(t, schemaObj)
	}

	// Test custom schema registration
	customSchema := schema.NewObjectSchema(
		map[string]types.Schema{
			"name": schema.NewStringSchema(),
			"age":  schema.NewIntSchema(),
		},
		[]string{"name"},
	)
	err := registry.Register(customSchema)
	require.NoError(t, err)

	// Test duplicate registration
	err = registry.Register(customSchema)
	require.Error(t, err)

	// Test schema retrieval
	schemaObj, err := registry.Get("object", "1.0")
	require.NoError(t, err)
	require.NotNil(t, schemaObj)

	// Test unknown schema
	_, err = registry.Get("unknown", "1.0")
	require.Error(t, err)

	// Test list types
	typesList := registry.ListTypes()
	require.Contains(t, typesList, "object")
	require.Contains(t, typesList, "string")

	// Test list versions
	versions, err := registry.ListVersions("object")
	require.NoError(t, err)
	require.Contains(t, versions, "1.0")
}

func TestListTypes(t *testing.T) {
	registry := schema.NewRegistry()

	// Test builtin schemas
	builtinTypes := []string{"string", "int", "float", "bool", "time", "any"}
	for _, typ := range builtinTypes {
		schemaObj, err := registry.GetLatest(typ)
		require.NoError(t, err)
		require.NotNil(t, schemaObj)
	}

	// Test custom schema registration
	customSchema := schema.NewObjectSchema(
		map[string]types.Schema{
			"name": schema.NewStringSchema(),
			"age":  schema.NewIntSchema(),
		},
		[]string{"name"},
	)
	err := registry.Register(customSchema)
	require.NoError(t, err)

	// Test duplicate registration
	err = registry.Register(customSchema)
	require.Error(t, err)

	// Test schema retrieval
	schemaObj, err := registry.Get("object", "1.0")
	require.NoError(t, err)
	require.NotNil(t, schemaObj)

	// Test unknown schema
	_, err = registry.Get("unknown", "1.0")
	require.Error(t, err)

	// Test list types
	schemaTypes := registry.ListTypes()
	require.Contains(t, schemaTypes, "object")
	require.Contains(t, schemaTypes, "string")

	// Test list versions
	versions, err := registry.ListVersions("object")
	require.NoError(t, err)
	require.Contains(t, versions, "1.0")
}
