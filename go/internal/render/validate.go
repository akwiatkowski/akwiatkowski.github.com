package render

import (
	"fmt"
	"strings"

	"golang.org/x/net/html"
)

// ValidationError describes a single validation issue.
type ValidationError struct {
	URL     string
	Message string
}

func (e ValidationError) Error() string {
	return fmt.Sprintf("%s: %s", e.URL, e.Message)
}

// ValidateHTML checks rendered HTML for common issues.
func ValidateHTML(url string, content []byte) []ValidationError {
	var errs []ValidationError
	s := string(content)

	// Only validate HTML pages
	if !strings.HasSuffix(url, ".html") {
		return nil
	}

	// Parse HTML
	doc, err := html.Parse(strings.NewReader(s))
	if err != nil {
		errs = append(errs, ValidationError{url, fmt.Sprintf("HTML parse error: %v", err)})
		return errs
	}

	// Check <title> exists and is non-empty
	if title := findTitle(doc); title == "" {
		errs = append(errs, ValidationError{url, "missing or empty <title>"})
	}

	// Check for empty href/src attributes
	ids := make(map[string]bool)
	var walk func(*html.Node)
	walk = func(n *html.Node) {
		if n.Type == html.ElementNode {
			for _, attr := range n.Attr {
				if (attr.Key == "href" || attr.Key == "src") && attr.Val == "" {
					errs = append(errs, ValidationError{url, fmt.Sprintf("empty %s on <%s>", attr.Key, n.Data)})
				}
				if attr.Key == "id" {
					if ids[attr.Val] {
						errs = append(errs, ValidationError{url, fmt.Sprintf("duplicate id=%q", attr.Val)})
					}
					ids[attr.Val] = true
				}
			}
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(doc)

	return errs
}

// findTitle traverses the DOM to find the <title> text content.
func findTitle(n *html.Node) string {
	if n.Type == html.ElementNode && n.Data == "title" {
		if n.FirstChild != nil && n.FirstChild.Type == html.TextNode {
			return strings.TrimSpace(n.FirstChild.Data)
		}
		return ""
	}
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if t := findTitle(c); t != "" {
			return t
		}
	}
	return ""
}
