package main

import (
	"bytes"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"text/template"
)

type TypeInfo struct {
	Name       string
	Fields     []string
	Methods    []string
	Implements []string
}

type FileContext struct {
	Package      string
	Description  string
	Imports      []string
	Types        []TypeInfo
	Interfaces   []TypeInfo
	Functions    []string
	Dependencies map[string][]string
	UsedBy       []string
	Provides     []string
	Requires     []string
}

const fileTemplate = `/*
Package {{.Package}} - {{.Description}}

Core Responsibilities:
{{- if .Provides}}
Provides:
{{- range .Provides}}
  - {{.}}
{{- end}}
{{- end}}

Dependencies:
{{- range .Requires}}
  - {{.}}
{{- end}}

Type Definitions:
{{- range .Types}}
  - {{.Name}}
    Fields:
    {{- range .Fields}}
      * {{.}}
    {{- end}}
    Methods:
    {{- range .Methods}}
      * {{.}}
    {{- end}}
    {{- if .Implements}}
    Implements:
    {{- range .Implements}}
      * {{.}}
    {{- end}}
    {{- end}}
{{- end}}

Interfaces:
{{- range .Interfaces}}
  - {{.Name}}
    Methods:
    {{- range .Methods}}
      * {{.}}
    {{- end}}
{{- end}}

Package Dependencies:
{{- range $pkg, $types := .Dependencies}}
  - {{$pkg}}:
    {{- range $types}}
    * {{.}}
    {{- end}}
{{- end}}

Used By:
{{- range .UsedBy}}
  - {{.}}
{{- end}}

For more details on specific types and functions, see the documentation below.
*/

`

func main() {
	if err := generateContext(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func generateContext() error {
	// Find all Go files
	var files []string
	err := filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && strings.HasSuffix(path, ".go") &&
			!strings.Contains(path, "vendor/") &&
			!strings.Contains(path, "scripts/") {
			files = append(files, path)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("failed to walk directory: %w", err)
	}

	// Parse each file and build context
	fset := token.NewFileSet()
	contexts := make(map[string]*FileContext)

	// First pass: collect basic information
	for _, file := range files {
		node, err := parser.ParseFile(fset, file, nil, parser.ParseComments)
		if err != nil {
			return fmt.Errorf("failed to parse %s: %w", file, err)
		}

		context := &FileContext{
			Package:      node.Name.Name,
			Dependencies: make(map[string][]string),
		}

		// Extract package description from comments
		if node.Doc != nil {
			context.Description = node.Doc.Text()
		}

		// Collect imports
		for _, imp := range node.Imports {
			path := strings.Trim(imp.Path.Value, "\"")
			context.Imports = append(context.Imports, path)
			if strings.Contains(path, "flow-control") {
				context.Requires = append(context.Requires, path)
			}
		}

		// Collect type information
		ast.Inspect(node, func(n ast.Node) bool {
			switch x := n.(type) {
			case *ast.TypeSpec:
				info := TypeInfo{Name: x.Name.Name}
				switch t := x.Type.(type) {
				case *ast.InterfaceType:
					if t.Methods != nil {
						for _, m := range t.Methods.List {
							if len(m.Names) > 0 {
								info.Methods = append(info.Methods, m.Names[0].Name)
							}
						}
					}
					context.Interfaces = append(context.Interfaces, info)
					context.Provides = append(context.Provides, fmt.Sprintf("Interface: %s", info.Name))
				case *ast.StructType:
					if t.Fields != nil {
						for _, f := range t.Fields.List {
							if len(f.Names) > 0 {
								info.Fields = append(info.Fields, f.Names[0].Name)
							}
						}
					}
					context.Types = append(context.Types, info)
					context.Provides = append(context.Provides, fmt.Sprintf("Type: %s", info.Name))
				}
			case *ast.FuncDecl:
				if x.Recv == nil {
					context.Functions = append(context.Functions, x.Name.Name)
					context.Provides = append(context.Provides, fmt.Sprintf("Function: %s", x.Name.Name))
				}
			}
			return true
		})

		contexts[file] = context
	}

	// Second pass: analyze relationships
	for file, ctx := range contexts {
		for _, imp := range ctx.Imports {
			if strings.Contains(imp, "flow-control") {
				parts := strings.Split(imp, "/")
				pkg := parts[len(parts)-1]
				for otherFile, otherCtx := range contexts {
					if otherCtx.Package == pkg {
						otherCtx.UsedBy = append(otherCtx.UsedBy, file)
						for _, t := range otherCtx.Types {
							ctx.Dependencies[otherFile] = append(
								ctx.Dependencies[otherFile],
								fmt.Sprintf("Type: %s", t.Name),
							)
						}
						for _, i := range otherCtx.Interfaces {
							ctx.Dependencies[otherFile] = append(
								ctx.Dependencies[otherFile],
								fmt.Sprintf("Interface: %s", i.Name),
							)
						}
					}
				}
			}
		}
	}

	// Generate and write documentation
	tmpl := template.New("file")
	tmpl.Funcs(template.FuncMap{
		"join": strings.Join,
	})
	tmpl, err = tmpl.Parse(fileTemplate)
	if err != nil {
		return fmt.Errorf("failed to parse template: %w", err)
	}

	for file, ctx := range contexts {
		var buf bytes.Buffer
		if err := tmpl.Execute(&buf, ctx); err != nil {
			return fmt.Errorf("failed to execute template for %s: %w", file, err)
		}

		// Read existing file
		content, err := ioutil.ReadFile(file)
		if err != nil {
			return fmt.Errorf("failed to read %s: %w", file, err)
		}

		// Remove existing package documentation
		lines := strings.Split(string(content), "\n")
		start := 0
		for i, line := range lines {
			if strings.HasPrefix(line, "package ") {
				start = i
				break
			}
		}

		// Combine new documentation with existing file
		newContent := buf.String() + strings.Join(lines[start:], "\n")
		if err := ioutil.WriteFile(file, []byte(newContent), 0644); err != nil {
			return fmt.Errorf("failed to write %s: %w", file, err)
		}
	}

	return nil
} 