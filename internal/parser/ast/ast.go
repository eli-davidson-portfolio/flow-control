/*
Package ast defines the abstract syntax tree (AST) for the Flow language.
It provides types and interfaces for representing the structure of Flow programs.
*/
package ast

import (
	"fmt"
	"strings"

	"flow-control/internal/parser/token"
)

// Node represents a node in the AST
type Node interface {
	TokenLiteral() string
	String() string
}

// Statement represents a statement in the AST
type Statement interface {
	Node
	statementNode()
}

// Expression represents an expression in the AST
type Expression interface {
	Node
	expressionNode()
}

// Program represents a complete flow program
type Program struct {
	Statements []Statement
}

// TokenLiteral returns the literal value of the first token in the program
func (p *Program) TokenLiteral() string {
	if len(p.Statements) > 0 {
		return p.Statements[0].TokenLiteral()
	}
	return ""
}

// String returns a string representation of the program
func (p *Program) String() string {
	var out strings.Builder
	for _, s := range p.Statements {
		out.WriteString(s.String())
	}
	return out.String()
}

// Flow represents a flow definition in the AST
type Flow struct {
	Token token.Token
	Name  *Identifier
	Body  *BlockStatement
}

func (f *Flow) statementNode() {}

// TokenLiteral returns the literal value of the flow's token
func (f *Flow) TokenLiteral() string { return f.Token.Literal }

// String returns a string representation of the flow
func (f *Flow) String() string {
	return fmt.Sprintf("flow %s %s", f.Name.String(), f.Body.String())
}

// FlowNode represents a node definition in the AST
type FlowNode struct {
	Token token.Token
	Name  *Identifier
	Body  *BlockStatement
}

func (n *FlowNode) statementNode() {}

// TokenLiteral returns the literal value of the node's token
func (n *FlowNode) TokenLiteral() string { return n.Token.Literal }

// String returns a string representation of the node
func (n *FlowNode) String() string {
	return fmt.Sprintf("node %s %s", n.Name.String(), n.Body.String())
}

// Config represents a config block in the AST
type Config struct {
	Token token.Token
	Body  *BlockStatement
}

func (c *Config) statementNode() {}

// TokenLiteral returns the literal value of the config's token
func (c *Config) TokenLiteral() string { return c.Token.Literal }

// String returns a string representation of the config
func (c *Config) String() string {
	if c.Body != nil {
		c.Body.Indent = 1 // Set initial indentation for config block
	}
	return fmt.Sprintf("config %s", c.Body.String())
}

// BlockStatement represents a block of statements in the AST
type BlockStatement struct {
	Token      token.Token
	Statements []Statement
	Indent     int // Track indentation level
}

func (bs *BlockStatement) statementNode() {}

// TokenLiteral returns the literal value of the block's token
func (bs *BlockStatement) TokenLiteral() string { return bs.Token.Literal }

// String returns a string representation of the block
func (bs *BlockStatement) String() string {
	var out strings.Builder
	indent := strings.Repeat("  ", bs.Indent)
	nextIndent := strings.Repeat("  ", bs.Indent+1)

	out.WriteString("{\n")
	for _, s := range bs.Statements {
		out.WriteString(nextIndent)
		// If statement is another block, set its indentation
		if block, ok := s.(*BlockStatement); ok {
			block.Indent = bs.Indent + 1
		}
		out.WriteString(s.String())
		out.WriteString("\n")
	}
	out.WriteString(indent)
	out.WriteString("}")
	return out.String()
}

// Assignment represents an assignment statement in the AST
type Assignment struct {
	Token token.Token
	Name  *Identifier
	Value Expression
}

func (a *Assignment) statementNode() {}

// TokenLiteral returns the literal value of the assignment's token
func (a *Assignment) TokenLiteral() string { return a.Token.Literal }

// String returns a string representation of the assignment
func (a *Assignment) String() string {
	return fmt.Sprintf("%s: %s", a.Name.String(), a.Value.String())
}

// Identifier represents an identifier in the AST
type Identifier struct {
	Token token.Token
	Value string
}

func (i *Identifier) expressionNode() {}

// TokenLiteral returns the literal value of the identifier's token
func (i *Identifier) TokenLiteral() string { return i.Token.Literal }

// String returns a string representation of the identifier
func (i *Identifier) String() string { return i.Value }

// StringLiteral represents a string literal in the AST
type StringLiteral struct {
	Token token.Token
	Value string
}

func (sl *StringLiteral) expressionNode() {}

// TokenLiteral returns the literal value of the string literal's token
func (sl *StringLiteral) TokenLiteral() string { return sl.Token.Literal }

// String returns a string representation of the string literal
func (sl *StringLiteral) String() string { return fmt.Sprintf("%q", sl.Value) }

// NumberLiteral represents a number literal in the AST
type NumberLiteral struct {
	Token token.Token
	Value float64
}

func (nl *NumberLiteral) expressionNode() {}

// TokenLiteral returns the literal value of the number literal's token
func (nl *NumberLiteral) TokenLiteral() string { return nl.Token.Literal }

// String returns a string representation of the number literal
func (nl *NumberLiteral) String() string { return fmt.Sprintf("%g", nl.Value) }
