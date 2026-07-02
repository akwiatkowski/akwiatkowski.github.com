// Package markdown provides a goldmark extension for parsing custom blog directives:
// {% photo %}, {% photo_header %}, {% post_url %}, {% geo %}, {% pro_tip %}, {% current_year %}, {% todo %}.
package content

import (
	"strconv"
	"strings"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/parser"
	"github.com/yuin/goldmark/text"
	"github.com/yuin/goldmark/util"
)

// --- AST Nodes ---

// KindPhoto is the AST node kind for {% photo %} directives.
var KindPhoto = ast.NewNodeKind("Photo")

// PhotoNode represents a {% photo "filename","caption","tags" %} directive.
type PhotoNode struct {
	ast.BaseBlock
	Filename string
	Caption  string
	Tags     []string // photo tag slugs (without "tag:" prefix)
}

func (n *PhotoNode) Kind() ast.NodeKind { return KindPhoto }
func (n *PhotoNode) Dump(src []byte, level int) {
	ast.DumpHelper(n, src, level, map[string]string{
		"Filename": n.Filename,
		"Caption":  n.Caption,
	}, nil)
}

// KindPhotoHeader is the AST node kind for {% photo_header %} directives.
var KindPhotoHeader = ast.NewNodeKind("PhotoHeader")

// PhotoHeaderNode represents a {% photo_header "caption","tags" %} directive.
type PhotoHeaderNode struct {
	ast.BaseBlock
	Caption string
	Tags    []string
}

func (n *PhotoHeaderNode) Kind() ast.NodeKind { return KindPhotoHeader }
func (n *PhotoHeaderNode) Dump(src []byte, level int) {
	ast.DumpHelper(n, src, level, map[string]string{
		"Caption": n.Caption,
	}, nil)
}

// KindPostURL is the AST node kind for {% post_url %} directives.
var KindPostURL = ast.NewNodeKind("PostURL")

// PostURLNode represents a {% post_url slug %} inline directive.
type PostURLNode struct {
	ast.BaseInline
	PostSlug string
}

func (n *PostURLNode) Kind() ast.NodeKind { return KindPostURL }
func (n *PostURLNode) Dump(src []byte, level int) {
	ast.DumpHelper(n, src, level, map[string]string{
		"PostSlug": n.PostSlug,
	}, nil)
}

// KindGeo is the AST node kind for {% geo %} directives.
var KindGeo = ast.NewNodeKind("Geo")

// GeoNode represents a {% geo lat,lon %} inline directive.
type GeoNode struct {
	ast.BaseInline
	Lat float64
	Lon float64
}

func (n *GeoNode) Kind() ast.NodeKind { return KindGeo }
func (n *GeoNode) Dump(src []byte, level int) {
	ast.DumpHelper(n, src, level, nil, nil)
}

// KindProTip is the AST node kind for {% pro_tip %} directives.
var KindProTip = ast.NewNodeKind("ProTip")

// ProTipNode represents a {% pro_tip %} inline directive.
type ProTipNode struct {
	ast.BaseInline
}

func (n *ProTipNode) Kind() ast.NodeKind { return KindProTip }
func (n *ProTipNode) Dump(src []byte, level int) {
	ast.DumpHelper(n, src, level, nil, nil)
}

// KindCurrentYear is the AST node kind for {% current_year %} directives.
var KindCurrentYear = ast.NewNodeKind("CurrentYear")

// CurrentYearNode represents a {% current_year %} inline directive.
type CurrentYearNode struct {
	ast.BaseInline
}

func (n *CurrentYearNode) Kind() ast.NodeKind { return KindCurrentYear }
func (n *CurrentYearNode) Dump(src []byte, level int) {
	ast.DumpHelper(n, src, level, nil, nil)
}

// KindTodo is the AST node kind for {% todo %} directives.
var KindTodo = ast.NewNodeKind("Todo")

// TodoNode represents a {% todo %} directive (produces no output).
type TodoNode struct {
	ast.BaseInline
}

func (n *TodoNode) Kind() ast.NodeKind { return KindTodo }
func (n *TodoNode) Dump(src []byte, level int) {
	ast.DumpHelper(n, src, level, nil, nil)
}

// --- Block Parser (photo, photo_header) ---

type directiveBlockParser struct{}

func (p *directiveBlockParser) Trigger() []byte {
	return []byte{'{'}
}

func (p *directiveBlockParser) Open(parent ast.Node, reader text.Reader, pc parser.Context) (ast.Node, parser.State) {
	line, _ := reader.PeekLine()
	trimmed := strings.TrimSpace(string(line))

	if !strings.HasPrefix(trimmed, "{%") || !strings.HasSuffix(trimmed, "%}") {
		return nil, parser.NoChildren
	}

	inner := strings.TrimSpace(trimmed[2 : len(trimmed)-2])

	if strings.HasPrefix(inner, "photo_header ") {
		args := inner[len("photo_header "):]
		caption, tags := parseHeaderArgs(args)
		reader.Advance(len(line))
		return &PhotoHeaderNode{Caption: caption, Tags: tags}, parser.NoChildren
	}

	if strings.HasPrefix(inner, "photo ") {
		args := inner[len("photo "):]
		filename, caption, tags := parsePhotoArgs(args)
		reader.Advance(len(line))
		return &PhotoNode{Filename: filename, Caption: caption, Tags: tags}, parser.NoChildren
	}

	return nil, parser.NoChildren
}

func (p *directiveBlockParser) Continue(node ast.Node, reader text.Reader, pc parser.Context) parser.State {
	return parser.Close
}

func (p *directiveBlockParser) Close(node ast.Node, reader text.Reader, pc parser.Context) {}

func (p *directiveBlockParser) CanInterruptParagraph() bool { return true }
func (p *directiveBlockParser) CanAcceptIndentedLine() bool { return false }

// --- Inline Parser (post_url, geo, pro_tip, current_year, todo) ---

type directiveInlineParser struct{}

func (p *directiveInlineParser) Trigger() []byte {
	return []byte{'{'}
}

func (p *directiveInlineParser) Parse(parent ast.Node, block text.Reader, pc parser.Context) ast.Node {
	line, seg := block.PeekLine()
	if len(line) < 2 || line[1] != '%' {
		return nil
	}

	s := string(line)
	end := strings.Index(s, "%}")
	if end < 0 {
		return nil
	}

	inner := strings.TrimSpace(s[2:end])
	consumed := end + 2
	_ = seg // segment tracking handled by Advance

	// {% post_url slug %}
	if strings.HasPrefix(inner, "post_url ") {
		slug := strings.TrimSpace(inner[len("post_url "):])
		if slug == "" {
			return nil
		}
		block.Advance(consumed)
		return &PostURLNode{PostSlug: slug}
	}

	// {% geo lat,lon %}
	if strings.HasPrefix(inner, "geo ") {
		args := strings.TrimSpace(inner[len("geo "):])
		lat, lon, ok := parseGeoArgs(args)
		if !ok {
			return nil
		}
		block.Advance(consumed)
		return &GeoNode{Lat: lat, Lon: lon}
	}

	// {% pro_tip %}
	if inner == "pro_tip" {
		block.Advance(consumed)
		return &ProTipNode{}
	}

	// {% current_year %}
	if inner == "current_year" {
		block.Advance(consumed)
		return &CurrentYearNode{}
	}

	// {% todo %}
	if inner == "todo" {
		block.Advance(consumed)
		return &TodoNode{}
	}

	return nil
}

// parseGeoArgs parses "52.45,16.93" → (52.45, 16.93, true)
func parseGeoArgs(s string) (lat, lon float64, ok bool) {
	parts := strings.SplitN(s, ",", 2)
	if len(parts) != 2 {
		return 0, 0, false
	}
	var err error
	lat, err = strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
	if err != nil {
		return 0, 0, false
	}
	lon, err = strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
	if err != nil {
		return 0, 0, false
	}
	return lat, lon, true
}

// --- Argument Parsing ---

// parsePhotoArgs parses: "filename","caption" or "filename","caption","tag:x,tag:y"
func parsePhotoArgs(s string) (filename, caption string, tags []string) {
	parts := splitQuotedArgs(s)
	if len(parts) >= 1 {
		filename = parts[0]
	}
	if len(parts) >= 2 {
		caption = parts[1]
	}
	if len(parts) >= 3 {
		tags = parseTags(parts[2])
	}
	return
}

// parseHeaderArgs parses: "caption","tag:x,tag:y" or just "caption"
func parseHeaderArgs(s string) (caption string, tags []string) {
	parts := splitQuotedArgs(s)
	if len(parts) >= 1 {
		caption = parts[0]
	}
	if len(parts) >= 2 {
		tags = parseTags(parts[1])
	}
	return
}

// splitQuotedArgs splits a comma-separated list of quoted strings.
// Input: `"foo","bar","baz"` → ["foo", "bar", "baz"]
func splitQuotedArgs(s string) []string {
	var result []string
	s = strings.TrimSpace(s)
	for s != "" {
		if s[0] == '"' {
			// Find closing quote
			end := strings.Index(s[1:], `"`)
			if end < 0 {
				result = append(result, s[1:])
				break
			}
			result = append(result, s[1:end+1])
			s = s[end+2:]
			// Skip comma
			s = strings.TrimLeft(s, ", ")
		} else {
			// Unquoted — take until comma
			end := strings.Index(s, ",")
			if end < 0 {
				result = append(result, strings.TrimSpace(s))
				break
			}
			result = append(result, strings.TrimSpace(s[:end]))
			s = strings.TrimLeft(s[end+1:], " ")
		}
	}
	return result
}

// parseTags splits "tag:good,tag:best" → ["good", "best"]
func parseTags(s string) []string {
	var tags []string
	for _, part := range strings.Split(s, ",") {
		part = strings.TrimSpace(part)
		if strings.HasPrefix(part, "tag:") {
			tags = append(tags, part[4:])
		}
	}
	return tags
}

// --- Extension ---

// Extension is a goldmark extension for custom blog directives.
type Extension struct{}

func (e *Extension) Extend(m goldmark.Markdown) {
	m.Parser().AddOptions(
		parser.WithBlockParsers(
			util.Prioritized(&directiveBlockParser{}, 50),
		),
		parser.WithInlineParsers(
			util.Prioritized(&directiveInlineParser{}, 50),
		),
	)
}

// --- Extraction ---

// ExtractedData holds photo refs and cross-references extracted from parsed markdown.
type ExtractedData struct {
	Photos      []PhotoRefData
	HeaderPhoto *PhotoRefData
	CrossRefs   []string // post slugs
}

// PhotoRefData is a photo reference extracted from markdown AST.
type PhotoRefData struct {
	Filename string
	Caption  string
	Tags     []string
	IsHeader bool
}

// Extract walks a goldmark AST and extracts all photo refs and cross-references.
func Extract(doc ast.Node) ExtractedData {
	var data ExtractedData

	_ = ast.Walk(doc, func(n ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			return ast.WalkContinue, nil
		}
		switch node := n.(type) {
		case *PhotoNode:
			data.Photos = append(data.Photos, PhotoRefData{
				Filename: node.Filename,
				Caption:  node.Caption,
				Tags:     node.Tags,
			})
		case *PhotoHeaderNode:
			ref := PhotoRefData{
				Caption:  node.Caption,
				Tags:     node.Tags,
				IsHeader: true,
			}
			data.HeaderPhoto = &ref
		case *PostURLNode:
			data.CrossRefs = append(data.CrossRefs, node.PostSlug)
		}
		return ast.WalkContinue, nil
	})

	return data
}
