package content

import (
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/model"
)

// mockCanonicalizer implements Canonicalizer for testing, mirroring
// router.CanonicalURL (base URL + path).
type mockCanonicalizer struct{}

func (mockCanonicalizer) CanonicalURL(path string) string {
	return "https://example.test" + path
}

// renderTestPostMarkdown renders source to Markdown with the shared fixtures
// from renderer_test.go, so the HTML and Markdown paths are exercised against
// identical post data.
func renderTestPostMarkdown(source string, post *model.Post, links LinkResolver) string {
	ctx := &RenderContext{
		Post:       post,
		PostLookup: &mockPostLookup{},
		URLBuilder: &mockURLBuilder{},
		Links:      links,
		Canonical:  mockCanonicalizer{},
	}
	return RenderPostMarkdown(source, ctx)
}

func TestRenderPostMarkdownPhoto(t *testing.T) {
	post := testPost()
	got := renderTestPostMarkdown(`Some text

{% photo "photo1.jpg","A beautiful view" %}

More text`, post, nil)

	want := "![A beautiful view](https://example.test/images/processed/2021-07-18-test-post_photo1.jpg_article.jpg)"
	if !strings.Contains(got, want) {
		t.Errorf("expected image markdown %q, got:\n%s", want, got)
	}
	// Surrounding prose must survive untouched.
	for _, prose := range []string{"Some text", "More text"} {
		if !strings.Contains(got, prose) {
			t.Errorf("prose %q lost, got:\n%s", prose, got)
		}
	}
}

// The caption comes from the resolved photo (photo.Desc), not the directive
// argument — matching how renderPhoto builds the HTML figure caption.
func TestRenderPostMarkdownPhotoCaptionFromPhoto(t *testing.T) {
	post := testPost()
	got := renderTestPostMarkdown(`{% photo "photo1.jpg","stale caption in source" %}`, post, nil)

	if strings.Contains(got, "stale caption in source") {
		t.Errorf("directive argument used instead of photo.Desc, got:\n%s", got)
	}
	if !strings.Contains(got, "![A beautiful view]") {
		t.Errorf("expected photo.Desc as alt text, got:\n%s", got)
	}
}

// A photo that is not in PublishedPhotos must vanish rather than emit a broken
// image link — the same skip rule the HTML renderer applies.
func TestRenderPostMarkdownSkipsUnpublishedPhoto(t *testing.T) {
	post := testPost()
	got := renderTestPostMarkdown(`before

{% photo "missing.jpg","Not published" %}

after`, post, nil)

	if strings.Contains(got, "missing.jpg") || strings.Contains(got, "Not published") {
		t.Errorf("unpublished photo leaked into markdown:\n%s", got)
	}
	if !strings.Contains(got, "before") || !strings.Contains(got, "after") {
		t.Errorf("surrounding prose lost:\n%s", got)
	}
}

func TestRenderPostMarkdownDirectives(t *testing.T) {
	post := testPost()
	lookup := &mockPostLookup{posts: map[string]*model.Post{
		"2020-01-01-other": {
			Slug: "2020-01-01-other",
			Date: time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC),
		},
	}}

	tests := []struct {
		name   string
		source string
		want   string
		absent string
	}{
		{
			name:   "pro_tip becomes bold label",
			source: `{% pro_tip %} weź wodę`,
			want:   "**Porada:**",
		},
		{
			name:   "geo becomes an OpenStreetMap link",
			source: `Punkt: {% geo 52.45,16.93 %}`,
			want:   "[52.45000, 16.93000](https://www.openstreetmap.org/?mlat=52.450000",
		},
		{
			name:   "todo produces nothing",
			source: `text {% todo %} more`,
			absent: "todo",
		},
		{
			name:   "photo_header produces nothing",
			source: `{% photo_header "Header caption" %}` + "\n\nbody",
			absent: "Header caption",
		},
		{
			name:   "unknown directive is dropped, not leaked",
			source: `text {% totally_unknown thing %} more`,
			absent: "totally_unknown",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			ctx := &RenderContext{
				Post:       post,
				PostLookup: lookup,
				URLBuilder: &mockURLBuilder{},
				Canonical:  mockCanonicalizer{},
			}
			got := RenderPostMarkdown(tc.source, ctx)

			if tc.want != "" && !strings.Contains(got, tc.want) {
				t.Errorf("expected %q, got:\n%s", tc.want, got)
			}
			if tc.absent != "" && strings.Contains(got, tc.absent) {
				t.Errorf("expected %q to be absent, got:\n%s", tc.absent, got)
			}
		})
	}
}

// post_url / land_path / tag_path must resolve to absolute URLs: the Markdown
// is read out of band, where a site-relative path has no base to resolve
// against.
func TestRenderPostMarkdownLinksAreAbsolute(t *testing.T) {
	post := testPost()
	lookup := &mockPostLookup{posts: map[string]*model.Post{
		"2020-01-01-other": {
			Slug: "2020-01-01-other",
			Date: time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC),
		},
	}}
	links := mockLinkResolver{
		lands: map[string]string{"rudawy": "/region/rudawy.html"},
		tags:  map[string]string{"main": "/tag/glowne.html"},
	}

	ctx := &RenderContext{
		Post:       post,
		PostLookup: lookup,
		URLBuilder: &mockURLBuilder{},
		Links:      links,
		Canonical:  mockCanonicalizer{},
	}

	got := RenderPostMarkdown(
		`[a]({% post_url 2020-01-01-other %}) [b]({% land_path rudawy %}) [c]({% tag_path main %})`, ctx)

	for _, want := range []string{
		"https://example.test/2020/01/01-other.html",
		"https://example.test/region/rudawy.html",
		"https://example.test/tag/glowne.html",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("expected absolute URL %q, got:\n%s", want, got)
		}
	}
}

// No `{%` or `%}` may survive into the output under any circumstances — that
// is the whole contract of the .md representation.
func TestRenderPostMarkdownLeavesNoTemplateSyntax(t *testing.T) {
	post := testPost()
	source := strings.Join([]string{
		`{% photo "photo1.jpg","A beautiful view" %}`,
		`{% photo "missing.jpg","gone" %}`,
		`{% photo_header "Header" %}`,
		`{% pro_tip %}`,
		`{% geo 52.45,16.93 %}`,
		`{% current_year %}`,
		`{% todo %}`,
		`{% bogus %}`,
	}, "\n\n")

	got := renderTestPostMarkdown(source, post, nil)

	if strings.Contains(got, "{%") || strings.Contains(got, "%}") {
		t.Errorf("template syntax leaked into markdown:\n%s", got)
	}
}

// Dropped block directives must not leave a growing run of blank lines behind.
func TestRenderPostMarkdownCollapsesBlankLines(t *testing.T) {
	post := testPost()
	got := renderTestPostMarkdown("start\n\n{% todo %}\n\n{% todo %}\n\nend", post, nil)

	if strings.Contains(got, "\n\n\n") {
		t.Errorf("blank-line run not collapsed: %q", got)
	}
}

// Markdown-significant characters in a caption must not break the image link.
func TestRenderPostMarkdownEscapesCaptionBrackets(t *testing.T) {
	post := testPost()
	post.PublishedPhotos[0].Desc = "Widok [z góry]"

	got := renderTestPostMarkdown(`{% photo "photo1.jpg","x" %}`, post, nil)

	if !strings.Contains(got, `![Widok \[z góry\]](`) {
		t.Errorf("caption brackets not escaped, got:\n%s", got)
	}
}
