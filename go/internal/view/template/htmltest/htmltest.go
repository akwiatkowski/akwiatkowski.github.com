// Package htmltest provides test helpers for asserting on rendered templ HTML
// using golang.org/x/net/html.
package htmltest

import (
	"bytes"
	"context"
	"strings"
	"testing"

	"github.com/a-h/templ"
	"golang.org/x/net/html"
)

// Node is a re-export of html.Node so test files can reference it
// without importing golang.org/x/net/html directly.
type Node = html.Node

// Render renders a templ component to a string.
func Render(t *testing.T, c templ.Component) string {
	t.Helper()
	var buf bytes.Buffer
	err := c.Render(context.Background(), &buf)
	if err != nil {
		t.Fatalf("render failed: %v", err)
	}
	return buf.String()
}

// Parse parses an HTML fragment and returns the root node.
func Parse(t *testing.T, htmlStr string) *html.Node {
	t.Helper()
	doc, err := html.Parse(strings.NewReader(htmlStr))
	if err != nil {
		t.Fatalf("html.Parse failed: %v", err)
	}
	return doc
}

// FindAll returns all nodes matching the predicate (depth-first).
func FindAll(node *html.Node, match func(*html.Node) bool) []*html.Node {
	var results []*html.Node
	var walk func(*html.Node)
	walk = func(n *html.Node) {
		if match(n) {
			results = append(results, n)
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(node)
	return results
}

// FindOne returns the first node matching the predicate, or nil.
func FindOne(node *html.Node, match func(*html.Node) bool) *html.Node {
	results := FindAll(node, match)
	if len(results) == 0 {
		return nil
	}
	return results[0]
}

// IsElement returns true if the node is an element with the given tag.
func IsElement(n *html.Node, tag string) bool {
	return n.Type == html.ElementNode && n.Data == tag
}

// HasAttr returns true if the element has an attribute with the given key and value.
func HasAttr(n *html.Node, key, value string) bool {
	for _, a := range n.Attr {
		if a.Key == key && a.Val == value {
			return true
		}
	}
	return false
}

// AttrVal returns the value of an attribute, or "".
func AttrVal(n *html.Node, key string) string {
	for _, a := range n.Attr {
		if a.Key == key {
			return a.Val
		}
	}
	return ""
}

// HasClass returns true if the element's class attribute contains the given class.
func HasClass(n *html.Node, class string) bool {
	classes := AttrVal(n, "class")
	for _, c := range strings.Fields(classes) {
		if c == class {
			return true
		}
	}
	return false
}

// InnerText collects all text content from a node and its descendants.
func InnerText(n *html.Node) string {
	var sb strings.Builder
	var walk func(*html.Node)
	walk = func(node *html.Node) {
		if node.Type == html.TextNode {
			sb.WriteString(node.Data)
		}
		for c := node.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(n)
	return sb.String()
}

// AssertContains fails the test if the HTML string does not contain the substring.
func AssertContains(t *testing.T, htmlStr, substr string) {
	t.Helper()
	if !strings.Contains(htmlStr, substr) {
		t.Errorf("expected HTML to contain %q, but it was not found", substr)
	}
}

// AssertNotContains fails the test if the HTML string contains the substring.
func AssertNotContains(t *testing.T, htmlStr, substr string) {
	t.Helper()
	if strings.Contains(htmlStr, substr) {
		t.Errorf("expected HTML NOT to contain %q, but it was found", substr)
	}
}

// FindByTag returns all elements with the given tag name.
func FindByTag(node *html.Node, tag string) []*html.Node {
	return FindAll(node, func(n *html.Node) bool {
		return IsElement(n, tag)
	})
}

// FindByClass returns all elements with the given CSS class.
func FindByClass(node *html.Node, class string) []*html.Node {
	return FindAll(node, func(n *html.Node) bool {
		return n.Type == html.ElementNode && HasClass(n, class)
	})
}
