package ast_test

import (
	"testing"

	"flow-control/internal/parser/ast"
	"flow-control/internal/parser/token"

	"github.com/stretchr/testify/require"
)

func TestAST(t *testing.T) {
	tests := []struct {
		name     string
		node     ast.Node
		expected string
	}{
		{
			name: "flow",
			node: &ast.Flow{
				Token: token.Token{Type: token.FLOW, Literal: "flow"},
				Name: &ast.Identifier{
					Token: token.Token{Type: token.IDENT, Literal: "test"},
					Value: "test",
				},
				Body: &ast.BlockStatement{
					Token: token.Token{Type: token.LBRACE, Literal: "{"},
					Statements: []ast.Statement{
						&ast.Config{
							Token: token.Token{Type: token.CONFIG, Literal: "config"},
							Body: &ast.BlockStatement{
								Token: token.Token{Type: token.LBRACE, Literal: "{"},
								Statements: []ast.Statement{
									&ast.Assignment{
										Token: token.Token{Type: token.IDENT, Literal: "retries"},
										Name: &ast.Identifier{
											Token: token.Token{Type: token.IDENT, Literal: "retries"},
											Value: "retries",
										},
										Value: &ast.NumberLiteral{
											Token: token.Token{Type: token.NUMBER, Literal: "3"},
											Value: 3,
										},
									},
								},
							},
						},
					},
				},
			},
			expected: `flow test {
  config {
    retries: 3
  }
}`,
		},
		{
			name: "node",
			node: &ast.FlowNode{
				Token: token.Token{Type: token.NODE, Literal: "node"},
				Name: &ast.Identifier{
					Token: token.Token{Type: token.IDENT, Literal: "source"},
					Value: "source",
				},
				Body: &ast.BlockStatement{
					Token: token.Token{Type: token.LBRACE, Literal: "{"},
					Statements: []ast.Statement{
						&ast.Assignment{
							Token: token.Token{Type: token.IDENT, Literal: "type"},
							Name: &ast.Identifier{
								Token: token.Token{Type: token.IDENT, Literal: "type"},
								Value: "type",
							},
							Value: &ast.StringLiteral{
								Token: token.Token{Type: token.STRING, Literal: "http"},
								Value: "http",
							},
						},
					},
				},
			},
			expected: `node source {
  type: "http"
}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.node.String()
			require.Equal(t, tt.expected, got)
		})
	}
}
