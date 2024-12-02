package types

// Schema represents a data type schema for Flow Control
type Schema interface {
	// Validate checks if the given data conforms to the schema
	Validate(data interface{}) error

	// GetType returns the schema type identifier
	GetType() string

	// GetVersion returns the schema version
	GetVersion() string
} 