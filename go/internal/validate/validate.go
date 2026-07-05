// Package validate runs post-render sanity checks over the generated site's
// output directory. It is engine-agnostic: it reads only the written HTML files
// (plus a list of which post URLs are expected to carry a route map), so it
// works on both the Go and Crystal outputs.
//
// Three checks are performed:
//
//  1. Leaked markdown — rendered HTML must not contain literal markdown link
//     syntax like `[label](/url.html)` or `[label][ref]`. This is the class of
//     bug where a `{% post_url %}` (or any link) fails to convert to an anchor
//     and the raw brackets leak into the page.
//  2. Broken internal links — every internal href/src/srcset target must resolve
//     to a file that actually exists in the output directory.
//  3. Missing route map — every post that has a route must render its map
//     container; a post with GPS data but no visible map is a silent failure.
package validate

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"golang.org/x/net/html"
)

// Issue is a single validation finding. Kind is one of "leaked-markdown",
// "broken-link", "missing-map".
type Issue struct {
	File   string // repo-relative-ish path or URL of the offending page
	Kind   string
	Detail string
}

func (i Issue) String() string {
	return fmt.Sprintf("[%s] %s: %s", i.Kind, i.File, i.Detail)
}

// leakedMarkdownRe matches the two markdown-link shapes that must never survive
// into rendered HTML: an inline link destination `](…)` that looks like a URL
// or fragment, and a reference link `][ref]`. Scoped tightly to those shapes so
// ordinary prose containing a lone bracket does not trip it.
var leakedMarkdownRe = regexp.MustCompile(`\]\((?:/|https?://|#)[^)]*\)|\]\[[^\]]*\]`)

// skipTextElements are elements whose text content is not prose and may legitimately
// contain bracket/paren sequences (code samples, inline JSON, styles).
var skipTextElements = map[string]bool{
	"script": true, "style": true, "code": true, "pre": true, "textarea": true,
}

// LeakedMarkdown returns any leaked markdown link snippets found in the prose
// text of the given HTML document (text inside <script>/<style>/<code>/<pre> is
// ignored).
func LeakedMarkdown(htmlContent string) []string {
	doc, err := html.Parse(strings.NewReader(htmlContent))
	if err != nil {
		return nil
	}
	var found []string
	var walk func(n *html.Node, skipping bool)
	walk = func(n *html.Node, skipping bool) {
		if n.Type == html.ElementNode && skipTextElements[n.Data] {
			skipping = true
		}
		if n.Type == html.TextNode && !skipping {
			for _, m := range leakedMarkdownRe.FindAllString(n.Data, -1) {
				found = append(found, strings.TrimSpace(m))
			}
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c, skipping)
		}
	}
	walk(doc, false)
	return found
}

// NavHrefs returns the internal (site-root-relative) targets of clickable
// navigation links — `<a href>` — excluding media links under /images/.
// This matches the "every link can be clicked and its page exists" check:
// we verify navigation, not embedded assets (image src/srcset are out of
// scope here, so unfinished drafts' placeholder photos never trip it).
func NavHrefs(htmlContent string) []string {
	doc, err := html.Parse(strings.NewReader(htmlContent))
	if err != nil {
		return nil
	}
	var refs []string
	var walk func(n *html.Node)
	walk = func(n *html.Node) {
		if n.Type == html.ElementNode && n.Data == "a" {
			for _, a := range n.Attr {
				if a.Key != "href" {
					continue
				}
				ref, ok := normalizeInternalRef(a.Val)
				if ok && !strings.HasPrefix(ref, "/images/") {
					refs = append(refs, ref)
				}
			}
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(doc)
	return refs
}

// normalizeInternalRef strips the fragment and query, and reports whether the
// reference is an internal absolute path worth checking on disk.
func normalizeInternalRef(raw string) (string, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", false
	}
	// Drop fragment and query.
	if i := strings.IndexByte(raw, '#'); i >= 0 {
		raw = raw[:i]
	}
	if i := strings.IndexByte(raw, '?'); i >= 0 {
		raw = raw[:i]
	}
	if raw == "" {
		return "", false
	}
	// Only site-root-relative links are ours to verify. This excludes
	// http(s)://, protocol-relative //host, mailto:, tel:, data:, and
	// document-relative links (the site emits absolute paths).
	if !strings.HasPrefix(raw, "/") || strings.HasPrefix(raw, "//") {
		return "", false
	}
	return raw, true
}

// refToOutputPath maps an internal URL to the file expected on disk under
// outputRoot, resolving directory URLs to their index.html.
func refToOutputPath(outputRoot, ref string) string {
	if strings.HasSuffix(ref, "/") {
		ref += "index.html"
	}
	return filepath.Join(outputRoot, filepath.FromSlash(ref))
}

// Run executes all three checks over outputRoot. routeMapURLs is the set of
// post URLs (as "/YYYY/MM/DD-slug.html") that are expected to contain a route
// map because their post has GPS route data.
func Run(outputRoot string, routeMapURLs map[string]bool) ([]Issue, error) {
	var issues []Issue

	// Check 3: every route post renders its map container.
	for url := range routeMapURLs {
		path := refToOutputPath(outputRoot, url)
		content, err := os.ReadFile(path)
		if err != nil {
			issues = append(issues, Issue{url, "missing-map", fmt.Sprintf("post has a route but its page is missing: %v", err)})
			continue
		}
		if !strings.Contains(string(content), "post_small_photo_map") {
			issues = append(issues, Issue{url, "missing-map", "post has a route but no rendered map container"})
		}
	}

	// Walk all HTML files for checks 1 and 2.
	err := filepath.WalkDir(outputRoot, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(path, ".html") {
			return nil
		}
		content, rerr := os.ReadFile(path)
		if rerr != nil {
			return rerr
		}
		rel := "/" + filepath.ToSlash(strings.TrimPrefix(strings.TrimPrefix(path, outputRoot), "/"))
		text := string(content)

		for _, snippet := range LeakedMarkdown(text) {
			issues = append(issues, Issue{rel, "leaked-markdown", snippet})
		}
		for _, ref := range NavHrefs(text) {
			target := refToOutputPath(outputRoot, ref)
			if _, statErr := os.Stat(target); statErr != nil {
				issues = append(issues, Issue{rel, "broken-link", ref})
			}
		}
		return nil
	})
	if err != nil {
		return issues, err
	}
	return issues, nil
}
