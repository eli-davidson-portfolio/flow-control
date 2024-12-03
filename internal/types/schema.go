package types

// Schema defines the interface for data validation
type Schema interface {
	// Validate validates the data against the schema
	Validate(data interface{}) error

	// GetType returns the schema type
	GetType() string

	// GetProperties returns the schema properties
	GetProperties() map[string]interface{}
} 