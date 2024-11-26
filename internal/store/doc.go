// Package store provides persistent storage for Flow Control.
//
// The store package implements a SQLite-based storage layer for flows and their
// associated data. It provides CRUD operations for flows and maintains their
// execution state.
//
// Key features:
//
// - Flow storage and retrieval
// - Flow status management
// - Event logging
// - Metrics collection
//
// Example usage:
//
//	store, err := store.New("data/flows.db", logger)
//	if err != nil {
//	    log.Fatal(err)
//	}
//	defer store.Close()
//
//	flow := &types.Flow{
//	    Name: "My Flow",
//	    Config: `flow "myFlow" { ... }`,
//	    Status: "ready",
//	}
//
//	if err := store.CreateFlow(flow); err != nil {
//	    log.Fatal(err)
//	}
//
// The store uses SQLite for persistence, which provides good performance for
// most use cases while maintaining simplicity and reliability.
package store
