package parser_test

import (
	"testing"

	"flow-control/internal/logger"
	"flow-control/internal/parser"
	"flow-control/internal/parser/ast"
	"flow-control/internal/parser/lexer"
	"flow-control/internal/parser/token"

	"github.com/stretchr/testify/require"
)

func TestParser(t *testing.T) {
	// Create logger
	log := logger.New()

	tests := []struct {
		name    string
		input   string
		want    *ast.Program
		wantErr bool
	}{
		{
			name: "simple flow",
			input: `flow "test" {
				config {
					retries: 3
				}
			}`,
			want: &ast.Program{
				Statements: []ast.Statement{
					&ast.Flow{
						Token: token.Token{Type: token.FLOW, Literal: "flow"},
						Name: &ast.Identifier{
							Token: token.Token{Type: token.STRING, Literal: "test"},
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
				},
			},
			wantErr: false,
		},
		{
			name: "invalid flow",
			input: `flow "test" {
				invalid syntax
			}`,
			want:    nil,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			l := lexer.New(tt.input)
			p := parser.New(l, log)

			got := p.ParseProgram()
			if tt.wantErr {
				require.NotEmpty(t, p.Errors())
				return
			}

			require.Empty(t, p.Errors())
			compareAST(t, tt.want, got)
		})
	}
}

// compareAST compares two AST nodes while ignoring token positions
func compareAST(t *testing.T, want, got ast.Node) {
	t.Helper()

	if want == nil && got == nil {
		return
	}

	require.NotNil(t, want)
	require.NotNil(t, got)
	require.Equal(t, want.String(), got.String())

	switch want := want.(type) {
	case *ast.Program:
		gotProg := got.(*ast.Program)
		require.Equal(t, len(want.Statements), len(gotProg.Statements))
		for i := range want.Statements {
			compareAST(t, want.Statements[i], gotProg.Statements[i])
		}
	case *ast.Flow:
		gotFlow := got.(*ast.Flow)
		compareAST(t, want.Name, gotFlow.Name)
		compareAST(t, want.Body, gotFlow.Body)
	case *ast.BlockStatement:
		gotBlock := got.(*ast.BlockStatement)
		require.Equal(t, len(want.Statements), len(gotBlock.Statements))
		for i := range want.Statements {
			compareAST(t, want.Statements[i], gotBlock.Statements[i])
		}
	case *ast.Config:
		gotConfig := got.(*ast.Config)
		compareAST(t, want.Body, gotConfig.Body)
	case *ast.FlowNode:
		gotNode := got.(*ast.FlowNode)
		compareAST(t, want.Name, gotNode.Name)
		compareAST(t, want.Body, gotNode.Body)
	case *ast.Assignment:
		gotAssign := got.(*ast.Assignment)
		compareAST(t, want.Name, gotAssign.Name)
		compareAST(t, want.Value, gotAssign.Value)
	case *ast.Identifier:
		gotIdent := got.(*ast.Identifier)
		require.Equal(t, want.Value, gotIdent.Value)
	case *ast.StringLiteral:
		gotStr := got.(*ast.StringLiteral)
		require.Equal(t, want.Value, gotStr.Value)
	case *ast.NumberLiteral:
		gotNum := got.(*ast.NumberLiteral)
		require.Equal(t, want.Value, gotNum.Value)
	default:
		t.Errorf("Unknown AST node type: %T", want)
	}
}
