// Package parser implements the Flow language parser.
//
// The parser package is responsible for parsing Flow language source code into an
// abstract syntax tree (AST). It consists of several components:
//
// - Lexer: Performs lexical analysis to convert source code into tokens
// - Parser: Converts tokens into an AST
// - AST: Defines the abstract syntax tree nodes
//
// Example Flow language code:
//
//	flow "myFlow" {
//	    config {
//	        retries: 3
//	        timeout: 1000
//	    }
//
//	    node "transformer" {
//	        type: "Transform"
//	        inputs {
//	            data: { type: "text" }
//	        }
//	    }
//	}
//
// The parser is designed to be flexible and extensible, making it easy to add new
// language features and node types.
package parser
