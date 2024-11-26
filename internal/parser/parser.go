package parser

import (
	"fmt"
	"strconv"

	"flow-control/internal/parser/ast"
	"flow-control/internal/parser/lexer"
	"flow-control/internal/parser/token"
	"flow-control/internal/types"
)

// Parser represents a Flow language parser
type Parser struct {
	l      *lexer.Lexer
	log    types.Logger
	errors []string

	curToken  token.Token
	peekToken token.Token
}

// New creates a new Parser instance
func New(l *lexer.Lexer, log types.Logger) *Parser {
	p := &Parser{
		l:   l,
		log: log,
	}

	// Read two tokens, so curToken and peekToken are both set
	p.nextToken()
	p.nextToken()

	return p
}

// Errors returns any parsing errors
func (p *Parser) Errors() []string {
	return p.errors
}

func (p *Parser) peekError(t token.TokenType) {
	msg := fmt.Sprintf("expected next token to be %s, got %s instead",
		t, p.peekToken.Type)
	p.errors = append(p.errors, msg)
}

func (p *Parser) nextToken() {
	p.curToken = p.peekToken
	p.peekToken = p.l.NextToken()
}

func (p *Parser) curTokenIs(t token.TokenType) bool {
	return p.curToken.Type == t
}

func (p *Parser) peekTokenIs(t token.TokenType) bool {
	return p.peekToken.Type == t
}

func (p *Parser) expectPeek(t token.TokenType) bool {
	if p.peekTokenIs(t) {
		p.nextToken()
		return true
	}
	p.peekError(t)
	return false
}

// ParseProgram parses a complete Flow program
func (p *Parser) ParseProgram() *ast.Program {
	program := &ast.Program{}
	program.Statements = []ast.Statement{}

	for !p.curTokenIs(token.EOF) {
		stmt := p.parseStatement()
		if stmt != nil {
			program.Statements = append(program.Statements, stmt)
		}
		p.nextToken()
	}

	return program
}

func (p *Parser) parseStatement() ast.Statement {
	switch p.curToken.Type {
	case token.FLOW:
		return p.parseFlow()
	case token.NODE:
		return p.parseFlowNode()
	case token.CONFIG:
		return p.parseConfig()
	case token.IDENT:
		return p.parseAssignment()
	default:
		return nil
	}
}

func (p *Parser) parseFlow() *ast.Flow {
	stmt := &ast.Flow{Token: p.curToken}

	if !p.expectPeek(token.STRING) {
		return nil
	}

	stmt.Name = &ast.Identifier{Token: p.curToken, Value: p.curToken.Literal}

	if !p.expectPeek(token.LBRACE) {
		return nil
	}

	stmt.Body = p.parseBlockStatement()

	return stmt
}

func (p *Parser) parseFlowNode() *ast.FlowNode {
	stmt := &ast.FlowNode{Token: p.curToken}

	if !p.expectPeek(token.STRING) {
		return nil
	}

	stmt.Name = &ast.Identifier{Token: p.curToken, Value: p.curToken.Literal}

	if !p.expectPeek(token.LBRACE) {
		return nil
	}

	stmt.Body = p.parseBlockStatement()

	return stmt
}

func (p *Parser) parseConfig() *ast.Config {
	stmt := &ast.Config{Token: p.curToken}

	if !p.expectPeek(token.LBRACE) {
		return nil
	}

	stmt.Body = p.parseBlockStatement()

	return stmt
}

func (p *Parser) parseAssignment() *ast.Assignment {
	stmt := &ast.Assignment{Token: p.curToken}

	stmt.Name = &ast.Identifier{Token: p.curToken, Value: p.curToken.Literal}

	if !p.expectPeek(token.COLON) {
		return nil
	}

	p.nextToken()

	stmt.Value = p.parseExpression()

	return stmt
}

func (p *Parser) parseExpression() ast.Expression {
	switch p.curToken.Type {
	case token.STRING:
		return &ast.StringLiteral{Token: p.curToken, Value: p.curToken.Literal}
	case token.NUMBER:
		value, err := strconv.ParseFloat(p.curToken.Literal, 64)
		if err != nil {
			msg := fmt.Sprintf("could not parse %q as float", p.curToken.Literal)
			p.errors = append(p.errors, msg)
			return nil
		}
		return &ast.NumberLiteral{Token: p.curToken, Value: value}
	case token.IDENT:
		return &ast.Identifier{Token: p.curToken, Value: p.curToken.Literal}
	default:
		return nil
	}
}

func (p *Parser) parseBlockStatement() *ast.BlockStatement {
	block := &ast.BlockStatement{Token: p.curToken}
	block.Statements = []ast.Statement{}

	p.nextToken()

	for !p.curTokenIs(token.RBRACE) && !p.curTokenIs(token.EOF) {
		stmt := p.parseStatement()
		if stmt != nil {
			block.Statements = append(block.Statements, stmt)
		}
		p.nextToken()
	}

	return block
}
