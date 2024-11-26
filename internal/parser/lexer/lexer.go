/*
Package lexer implements lexical analysis for the Flow language.
It converts source code into a stream of tokens that can be consumed by the parser.
*/
package lexer

import (
	"flow-control/internal/parser/token"
	"strings"
)

// Lexer performs lexical analysis of the input
type Lexer struct {
	input        string
	position     int  // current position in input (points to current char)
	readPosition int  // current reading position in input (after current char)
	ch           byte // current char under examination
	line         int  // current line number (1-based)
	column       int  // current column number (0-based)
}

// New creates a new Lexer instance
func New(input string) *Lexer {
	l := &Lexer{
		input:  input,
		line:   1,
		column: -1,
	}
	l.readChar()
	return l
}

func (l *Lexer) readChar() {
	if l.readPosition >= len(l.input) {
		l.ch = 0
	} else {
		l.ch = l.input[l.readPosition]
	}

	l.position = l.readPosition
	l.readPosition++

	if l.ch == '\n' {
		l.line++
		l.column = -1
	}
	l.column++
}

func (l *Lexer) peekChar() byte {
	if l.readPosition >= len(l.input) {
		return 0
	}
	return l.input[l.readPosition]
}

// NextToken returns the next token from the input
func (l *Lexer) NextToken() token.Token {
	var tok token.Token

	l.skipWhitespace()

	startPos := token.Position{
		Line:   l.line,
		Column: l.column + 1,
	}

	switch {
	case l.ch == '"':
		tok.Type = token.STRING
		tok.Literal = l.readString()
		tok.Pos = token.Position{
			Line:   startPos.Line,
			Column: startPos.Column + 1,
		}
		return tok
	case l.ch == '{':
		tok = newToken(token.LBRACE, l.ch)
	case l.ch == '}':
		tok = newToken(token.RBRACE, l.ch)
	case l.ch == '[':
		tok = newToken(token.LBRACKET, l.ch)
	case l.ch == ']':
		tok = newToken(token.RBRACKET, l.ch)
	case l.ch == ':':
		tok = newToken(token.COLON, l.ch)
	case l.ch == ',':
		tok = newToken(token.COMMA, l.ch)
	case l.ch == '/':
		if l.peekChar() == '/' {
			tok.Type = token.COMMENT
			tok.Literal = strings.TrimSpace(l.readLineComment())
			tok.Pos = startPos
			return tok
		}
		tok = newToken(token.ILLEGAL, l.ch)
	case l.ch == 0:
		tok.Literal = ""
		tok.Type = token.EOF
		tok.Pos = token.Position{
			Line:   l.line,
			Column: l.column,
		}
		return tok
	case isLetter(l.ch):
		tok.Literal = l.readIdentifier()
		tok.Type = token.LookupIdent(tok.Literal)
		tok.Pos = startPos
		return tok
	case isDigit(l.ch):
		tok.Literal = l.readNumber()
		tok.Type = token.NUMBER
		tok.Pos = startPos
		return tok
	default:
		tok = newToken(token.ILLEGAL, l.ch)
	}

	tok.Pos = startPos
	l.readChar()
	return tok
}

func (l *Lexer) readString() string {
	l.readChar() // skip opening quote
	position := l.position

	for {
		if l.ch == '"' {
			break
		}
		if l.ch == 0 {
			return l.input[position:l.position] // Return unterminated string
		}
		if l.ch == '\\' && l.peekChar() == '"' {
			l.readChar() // skip escape char
		}
		l.readChar()
	}

	str := l.input[position:l.position]
	l.readChar() // consume closing quote
	return str
}

func (l *Lexer) readIdentifier() string {
	position := l.position
	for isLetter(l.ch) || isDigit(l.ch) {
		l.readChar()
	}
	return l.input[position:l.position]
}

func (l *Lexer) readNumber() string {
	position := l.position
	for isDigit(l.ch) {
		l.readChar()
	}
	return l.input[position:l.position]
}

func (l *Lexer) readLineComment() string {
	l.readChar() // skip first /
	l.readChar() // skip second /

	position := l.position

	for l.ch != '\n' && l.ch != 0 {
		l.readChar()
	}

	return l.input[position:l.position]
}

func (l *Lexer) skipWhitespace() {
	for l.ch == ' ' || l.ch == '\t' || l.ch == '\n' || l.ch == '\r' {
		l.readChar()
	}
}

func newToken(tokenType token.TokenType, ch byte) token.Token {
	return token.Token{Type: tokenType, Literal: string(ch)}
}

func isLetter(ch byte) bool {
	return 'a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' || ch == '_'
}

func isDigit(ch byte) bool {
	return '0' <= ch && ch <= '9'
}
