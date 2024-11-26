/*
Package token defines the tokens used by the Flow language lexer and parser.
It provides token types, constants, and utility functions for token handling.
*/
package token

import "fmt"

// Package token defines the tokens used by the Flow language lexer and parser.
// It provides token types, constants, and utility functions for token handling.

// Position represents a position in the source code
type Position struct {
	Line   int
	Column int
	Offset int
}

func (p Position) String() string {
	return fmt.Sprintf("Line %d, Column %d", p.Line, p.Column)
}

// TokenType represents the type of a token
type TokenType int

const (
	// ILLEGAL represents an illegal/unknown token
	ILLEGAL TokenType = iota
	// EOF represents the end of file token
	EOF
	// COMMENT represents a comment in the source code
	COMMENT

	// IDENT represents an identifier token
	IDENT
	// STRING represents a string literal token
	STRING
	// NUMBER represents a numeric literal token
	NUMBER

	// ASSIGN represents an assignment operator token
	ASSIGN
	// COLON represents a colon token
	COLON

	// COMMA represents a comma token
	COMMA
	// SEMICOLON represents a semicolon token
	SEMICOLON
	// LPAREN represents a left parenthesis token
	LPAREN
	// RPAREN represents a right parenthesis token
	RPAREN
	// LBRACE represents a left brace token
	LBRACE
	// RBRACE represents a right brace token
	RBRACE
	// LBRACKET represents a left bracket token
	LBRACKET
	// RBRACKET represents a right bracket token
	RBRACKET

	// FLOW represents the 'flow' keyword token
	FLOW
	// NODE represents the 'node' keyword token
	NODE
	// CONFIG represents the 'config' keyword token
	CONFIG
	// NODETYPE represents the 'nodeType' keyword token
	NODETYPE
	// TYPE represents the 'type' keyword token
	TYPE
	// FROM represents the 'from' keyword token
	FROM
	// TO represents the 'to' keyword token
	TO
	// INPUTS represents the 'inputs' keyword token
	INPUTS
	// OUTPUTS represents the 'outputs' keyword token
	OUTPUTS
)

// Token represents a lexical token
type Token struct {
	Type    TokenType
	Literal string
	Pos     Position
}

// String returns a string representation of the token type
func (tt TokenType) String() string {
	tokenNames := map[TokenType]string{
		ILLEGAL:   "ILLEGAL",
		EOF:       "EOF",
		COMMENT:   "COMMENT",
		IDENT:     "IDENT",
		STRING:    "STRING",
		NUMBER:    "NUMBER",
		ASSIGN:    "ASSIGN",
		COLON:     "COLON",
		COMMA:     "COMMA",
		SEMICOLON: "SEMICOLON",
		LPAREN:    "LPAREN",
		RPAREN:    "RPAREN",
		LBRACE:    "LBRACE",
		RBRACE:    "RBRACE",
		LBRACKET:  "LBRACKET",
		RBRACKET:  "RBRACKET",
		FLOW:      "FLOW",
		NODE:      "NODE",
		CONFIG:    "CONFIG",
		NODETYPE:  "NODETYPE",
		TYPE:      "TYPE",
		FROM:      "FROM",
		TO:        "TO",
		INPUTS:    "INPUTS",
		OUTPUTS:   "OUTPUTS",
	}

	if name, ok := tokenNames[tt]; ok {
		return name
	}
	return fmt.Sprintf("TokenType(%d)", tt)
}

// String returns a string representation of the token
func (t Token) String() string {
	return fmt.Sprintf("%s(%q) at %s", t.Type, t.Literal, t.Pos)
}

// Keywords maps keyword strings to their token types
var Keywords = map[string]TokenType{
	"flow":     FLOW,
	"node":     NODE,
	"config":   CONFIG,
	"nodeType": NODETYPE,
	"type":     TYPE,
	"from":     FROM,
	"to":       TO,
	"inputs":   INPUTS,
	"outputs":  OUTPUTS,
}

// LookupIdent checks if an identifier is a keyword
func LookupIdent(ident string) TokenType {
	if tok, ok := Keywords[ident]; ok {
		return tok
	}
	return IDENT
}
