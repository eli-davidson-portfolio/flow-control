package lexer_test

import (
	"testing"

	"flow-control/internal/parser/lexer"
	"flow-control/internal/parser/token"
)

func TestNextToken(t *testing.T) {
	input := `flow "myFlow" {
		config {
			retries: 3,
			timeout: 1000
		}
		
		// This is a comment
		node "transformer" {
			nodeType: "Transform"
			inputs {
				dataIn: {
					type: "text"
				}
			}
		}
	}`

	tests := []struct {
		expectedType    token.TokenType
		expectedLiteral string
		expectedLine    int
		expectedColumn  int
	}{
		{token.FLOW, "flow", 1, 1},
		{token.STRING, "myFlow", 1, 7},
		{token.LBRACE, "{", 1, 15},
		{token.CONFIG, "config", 2, 4},
		{token.LBRACE, "{", 2, 11},
		{token.IDENT, "retries", 3, 5},
		{token.COLON, ":", 3, 12},
		{token.NUMBER, "3", 3, 14},
		{token.COMMA, ",", 3, 15},
		{token.IDENT, "timeout", 4, 5},
		{token.COLON, ":", 4, 12},
		{token.NUMBER, "1000", 4, 14},
		{token.RBRACE, "}", 5, 4},
		{token.COMMENT, "This is a comment", 7, 4},
		{token.NODE, "node", 8, 4},
		{token.STRING, "transformer", 8, 10},
		{token.LBRACE, "{", 8, 23},
		{token.NODETYPE, "nodeType", 9, 5},
		{token.COLON, ":", 9, 13},
		{token.STRING, "Transform", 9, 16},
		{token.INPUTS, "inputs", 10, 5},
		{token.LBRACE, "{", 10, 12},
		{token.IDENT, "dataIn", 11, 6},
		{token.COLON, ":", 11, 12},
		{token.LBRACE, "{", 11, 14},
		{token.TYPE, "type", 12, 7},
		{token.COLON, ":", 12, 11},
		{token.STRING, "text", 12, 14},
		{token.RBRACE, "}", 13, 6},
		{token.RBRACE, "}", 14, 5},
		{token.RBRACE, "}", 15, 4},
		{token.RBRACE, "}", 16, 3},
		{token.EOF, "", 16, 3},
	}

	l := lexer.New(input)

	for i, tt := range tests {
		tok := l.NextToken()

		if tok.Type != tt.expectedType {
			t.Errorf("tests[%d] - tokentype wrong. expected=%q, got=%q",
				i, tt.expectedType, tok.Type)
		}

		if tok.Literal != tt.expectedLiteral {
			t.Errorf("tests[%d] - literal wrong. expected=%q, got=%q",
				i, tt.expectedLiteral, tok.Literal)
		}

		if tok.Pos.Line != tt.expectedLine {
			t.Errorf("tests[%d] - line wrong. expected=%d, got=%d",
				i, tt.expectedLine, tok.Pos.Line)
		}

		if tok.Pos.Column != tt.expectedColumn {
			t.Errorf("tests[%d] - column wrong. expected=%d, got=%d",
				i, tt.expectedColumn, tok.Pos.Column)
		}
	}
}

func TestEdgeCases(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected []struct {
			typ     token.TokenType
			literal string
		}
	}{
		{
			name:  "empty input",
			input: "",
			expected: []struct {
				typ     token.TokenType
				literal string
			}{
				{token.EOF, ""},
			},
		},
		{
			name:  "whitespace only",
			input: "   \n\t  \r\n",
			expected: []struct {
				typ     token.TokenType
				literal string
			}{
				{token.EOF, ""},
			},
		},
		{
			name:  "unterminated string",
			input: `"hello`,
			expected: []struct {
				typ     token.TokenType
				literal string
			}{
				{token.STRING, "hello"},
				{token.EOF, ""},
			},
		},
		{
			name:  "escaped quotes in string",
			input: `"hello\"world"`,
			expected: []struct {
				typ     token.TokenType
				literal string
			}{
				{token.STRING, `hello\"world`},
				{token.EOF, ""},
			},
		},
		{
			name:  "multiple comments",
			input: "// comment 1\n// comment 2",
			expected: []struct {
				typ     token.TokenType
				literal string
			}{
				{token.COMMENT, "comment 1"},
				{token.COMMENT, "comment 2"},
				{token.EOF, ""},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			l := lexer.New(tt.input)

			for i, expected := range tt.expected {
				tok := l.NextToken()

				if tok.Type != expected.typ {
					t.Errorf("tests[%d] - tokentype wrong. expected=%q, got=%q",
						i, expected.typ, tok.Type)
				}

				if tok.Literal != expected.literal {
					t.Errorf("tests[%d] - literal wrong. expected=%q, got=%q",
						i, expected.literal, tok.Literal)
				}
			}
		})
	}
}

func TestIllegalCharacters(t *testing.T) {
	input := "@#$"
	l := lexer.New(input)

	for _, expected := range []byte(input) {
		tok := l.NextToken()
		if tok.Type != token.ILLEGAL {
			t.Errorf("expected ILLEGAL token for char %q, got %q", expected, tok.Type)
		}
		if tok.Literal != string(expected) {
			t.Errorf("expected literal %q, got %q", string(expected), tok.Literal)
		}
	}
}
