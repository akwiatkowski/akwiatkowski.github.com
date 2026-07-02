package render

import (
	"bytes"
	"io"
	"strings"

	"golang.org/x/net/html"
)

// PrettyPrint formats HTML with proper indentation.
// Preserves content of <pre>, <script>, <style>, <textarea> verbatim.
func PrettyPrint(input []byte) ([]byte, error) {
	doc, err := html.Parse(bytes.NewReader(input))
	if err != nil {
		return nil, err
	}

	var buf bytes.Buffer
	prettyWalk(&buf, doc, 0)
	return buf.Bytes(), nil
}

// Block-level elements that should be indented.
var blockElements = map[string]bool{
	"html": true, "head": true, "body": true,
	"div": true, "section": true, "article": true, "aside": true,
	"header": true, "footer": true, "nav": true, "main": true,
	"ul": true, "ol": true, "li": true, "dl": true, "dt": true, "dd": true,
	"table": true, "thead": true, "tbody": true, "tfoot": true, "tr": true,
	"th": true, "td": true,
	"form": true, "fieldset": true, "figure": true, "figcaption": true,
	"p": true, "h1": true, "h2": true, "h3": true, "h4": true, "h5": true, "h6": true,
	"blockquote": true, "details": true, "summary": true,
	"picture": true,
}

// Elements whose content should be preserved verbatim.
var preserveContent = map[string]bool{
	"pre": true, "script": true, "style": true, "textarea": true,
}

// Self-closing (void) elements.
var voidElements = map[string]bool{
	"area": true, "base": true, "br": true, "col": true, "embed": true,
	"hr": true, "img": true, "input": true, "link": true, "meta": true,
	"source": true, "track": true, "wbr": true,
}

func prettyWalk(w io.Writer, n *html.Node, depth int) {
	switch n.Type {
	case html.DocumentNode:
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			prettyWalk(w, c, depth)
		}
	case html.DoctypeNode:
		io.WriteString(w, "<!doctype html>\n")
	case html.ElementNode:
		if preserveContent[n.Data] {
			writePreserved(w, n, depth)
			return
		}

		isBlock := blockElements[n.Data]
		if isBlock {
			writeIndent(w, depth)
		}

		// Open tag
		io.WriteString(w, "<")
		io.WriteString(w, n.Data)
		for _, attr := range n.Attr {
			io.WriteString(w, " ")
			if attr.Namespace != "" {
				io.WriteString(w, attr.Namespace)
				io.WriteString(w, ":")
			}
			io.WriteString(w, attr.Key)
			io.WriteString(w, `="`)
			io.WriteString(w, html.EscapeString(attr.Val))
			io.WriteString(w, `"`)
		}

		if voidElements[n.Data] {
			io.WriteString(w, "/>")
			if isBlock {
				io.WriteString(w, "\n")
			}
			return
		}

		io.WriteString(w, ">")

		// Check if content is inline-only (no block children)
		hasBlockChildren := false
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			if c.Type == html.ElementNode && blockElements[c.Data] {
				hasBlockChildren = true
				break
			}
		}

		if hasBlockChildren || isBlock {
			io.WriteString(w, "\n")
			for c := n.FirstChild; c != nil; c = c.NextSibling {
				prettyWalk(w, c, depth+1)
			}
			writeIndent(w, depth)
		} else {
			for c := n.FirstChild; c != nil; c = c.NextSibling {
				prettyWalk(w, c, depth+1)
			}
		}

		// Close tag
		io.WriteString(w, "</")
		io.WriteString(w, n.Data)
		io.WriteString(w, ">")
		if isBlock {
			io.WriteString(w, "\n")
		}

	case html.TextNode:
		text := n.Data
		trimmed := strings.TrimSpace(text)
		if trimmed == "" {
			return
		}
		// If parent is block element, indent text
		if n.Parent != nil && n.Parent.Type == html.ElementNode && blockElements[n.Parent.Data] {
			writeIndent(w, depth)
			io.WriteString(w, trimmed)
			io.WriteString(w, "\n")
		} else {
			// Inline context: whitespace between inline siblings is significant
			// (e.g. ", " between links). Keep a single space on each side where
			// the source had one and a sibling exists to separate from.
			if n.PrevSibling != nil && len(text) > 0 && isSpaceByte(text[0]) {
				io.WriteString(w, " ")
			}
			io.WriteString(w, trimmed)
			if n.NextSibling != nil && isSpaceByte(text[len(text)-1]) {
				io.WriteString(w, " ")
			}
		}

	case html.CommentNode:
		writeIndent(w, depth)
		io.WriteString(w, "<!--")
		io.WriteString(w, n.Data)
		io.WriteString(w, "-->\n")
	}
}

func writePreserved(w io.Writer, n *html.Node, depth int) {
	writeIndent(w, depth)
	io.WriteString(w, "<")
	io.WriteString(w, n.Data)
	for _, attr := range n.Attr {
		io.WriteString(w, " ")
		if attr.Namespace != "" {
			io.WriteString(w, attr.Namespace)
			io.WriteString(w, ":")
		}
		io.WriteString(w, attr.Key)
		io.WriteString(w, `="`)
		io.WriteString(w, html.EscapeString(attr.Val))
		io.WriteString(w, `"`)
	}
	io.WriteString(w, ">")

	// Write children as raw text (no HTML escaping for script/style/pre content)
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if c.Type == html.TextNode {
			io.WriteString(w, c.Data)
		} else {
			// For non-text children (unlikely in script/pre), use html.Render
			var buf bytes.Buffer
			_ = html.Render(&buf, c)
			w.Write(buf.Bytes())
		}
	}

	io.WriteString(w, "</")
	io.WriteString(w, n.Data)
	io.WriteString(w, ">\n")
}

func writeIndent(w io.Writer, depth int) {
	for i := 0; i < depth; i++ {
		io.WriteString(w, "  ")
	}
}

// isSpaceByte reports whether b is an ASCII whitespace character.
// Used to detect significant leading/trailing whitespace in inline text nodes.
func isSpaceByte(b byte) bool {
	return b == ' ' || b == '\t' || b == '\n' || b == '\r'
}
