package validate

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLeakedMarkdownDetectsLeakedLink(t *testing.T) {
	// The exact regression: a post_url that failed to become an anchor.
	html := `<p>Dalej ([osobny wpis](/2020/10/10-kolejowe-roztocze.html)).</p>`
	got := LeakedMarkdown(html)
	if len(got) == 0 {
		t.Fatalf("expected a leaked-markdown finding, got none")
	}
	if !strings.Contains(got[0], "](/2020/10/10") {
		t.Errorf("unexpected snippet: %q", got[0])
	}
}

func TestLeakedMarkdownDetectsReferenceLink(t *testing.T) {
	html := `<p>zobacz [Ińsko][wiki-insko] w dolinie.</p>`
	if got := LeakedMarkdown(html); len(got) == 0 {
		t.Errorf("expected reference-link leak to be flagged, got none")
	}
}

func TestLeakedMarkdownIgnoresProperAnchor(t *testing.T) {
	html := `<p>Dalej (<a href="/2020/10/10-x.html">osobny wpis</a>).</p>`
	if got := LeakedMarkdown(html); len(got) != 0 {
		t.Errorf("proper anchor should not be flagged, got: %v", got)
	}
}

func TestLeakedMarkdownIgnoresCodeAndScripts(t *testing.T) {
	// Bracket/paren sequences inside code or scripts are not prose leaks.
	html := `<pre><code>arr[0](x)</code></pre><script>var a=[b](c);</script>` +
		`<p>Zwykły tekst ze spisem [1] i nawiasem (2).</p>`
	if got := LeakedMarkdown(html); len(got) != 0 {
		t.Errorf("expected no findings, got: %v", got)
	}
}

func TestNavHrefs(t *testing.T) {
	// Only clickable navigation links (<a href>) to internal pages count.
	// Media (<img>/<source>), external schemes, fragments and image links
	// are excluded — the check is about "link pages", not embedded assets.
	html := `
		<a href="/2020/10/10-x.html">page</a>
		<a href="/wpisy-dla/tagu/rowerem.html?v=1">tag</a>
		<img src="/images/a.jpg"/>
		<source srcset="/img/a-560.jpg 560w"/>
		<a href="/images/2020/x/photo.jpg">full-size image</a>
		<a href="https://example.com/ext">ext</a>
		<a href="#map">frag</a>
		<a href="mailto:x@y.z">mail</a>
		<a href="//fonts.example/f.css">proto-rel</a>`
	got := NavHrefs(html)
	want := map[string]bool{
		"/2020/10/10-x.html":           true,
		"/wpisy-dla/tagu/rowerem.html": true, // query stripped
	}
	if len(got) != len(want) {
		t.Fatalf("got %d hrefs %v, want %d", len(got), got, len(want))
	}
	for _, r := range got {
		if !want[r] {
			t.Errorf("unexpected nav href: %q", r)
		}
	}
}

func TestRunFindsBrokenLinkAndMissingMapAndLeak(t *testing.T) {
	root := t.TempDir()
	write := func(rel, content string) {
		p := filepath.Join(root, filepath.FromSlash(rel))
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	// A good asset target that exists.
	write("/css/main.css", "body{}")
	// Route post WITHOUT the map container → missing-map.
	write("/2020/10/09-route.html", `<html><body><a href="/css/main.css">css</a></body></html>`)
	// A page with a broken internal link and a leaked markdown link.
	write("/2021/01/01-x.html", `<html><body>`+
		`<a href="/css/missing.css">broken</a>`+
		`<p>see [here](/2021/01/02-y.html)</p>`+
		`</body></html>`)

	routeMapURLs := map[string]bool{"/2020/10/09-route.html": true}
	issues, err := Run(root, routeMapURLs)
	if err != nil {
		t.Fatal(err)
	}

	var kinds []string
	for _, is := range issues {
		kinds = append(kinds, is.Kind)
	}
	joined := strings.Join(kinds, ",")
	for _, want := range []string{"missing-map", "broken-link", "leaked-markdown"} {
		if !strings.Contains(joined, want) {
			t.Errorf("expected a %q issue; got kinds: %v", want, kinds)
		}
	}
}

func TestRunCleanSitePasses(t *testing.T) {
	root := t.TempDir()
	write := func(rel, content string) {
		p := filepath.Join(root, filepath.FromSlash(rel))
		_ = os.MkdirAll(filepath.Dir(p), 0o755)
		_ = os.WriteFile(p, []byte(content), 0o644)
	}
	write("/css/main.css", "body{}")
	write("/2020/10/09-route.html", `<html><body>`+
		`<div class="post_small_photo_map"></div>`+
		`<a href="/css/main.css">css</a>`+
		`<a href="/2020/10/09-route.html#top">self</a>`+
		`</body></html>`)

	issues, err := Run(root, map[string]bool{"/2020/10/09-route.html": true})
	if err != nil {
		t.Fatal(err)
	}
	if len(issues) != 0 {
		t.Errorf("clean site should have no issues, got: %v", issues)
	}
}
