package content

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/model"
)

// mockPostLookup implements PostLookup for testing.
type mockPostLookup struct {
	posts map[string]*model.Post
}

func (m *mockPostLookup) PostBySlug(slug string) *model.Post {
	return m.posts[slug]
}

// mockURLBuilder implements PostURLBuilder for testing.
type mockURLBuilder struct{}

func (m *mockURLBuilder) PostURL(post *model.Post) string {
	return fmt.Sprintf("/%d/%02d/%s.html", post.Date.Year(), post.Date.Month(), post.Slug[8:])
}

func (m *mockURLBuilder) ProcessedImageURL(post *model.Post, filename, size, format string) string {
	return "/images/processed/" + post.Slug + "_" + filename + "_" + size + "." + format
}

func (m *mockURLBuilder) PostImageURL(post *model.Post, filename string) string {
	return "/images/" + post.Slug + "/" + filename
}

func (m *mockURLBuilder) TagGalleryURL(tag *model.Tag) string {
	return "/galeria/tag/" + tag.SlugPl + ".html"
}

func testPost() *model.Post {
	iso := 400
	focal := 50.0
	aperture := 4.0
	lat := 52.45
	lon := 16.93

	return &model.Post{
		Slug:    "2021-07-18-test-post",
		Title:   "Test Post",
		Date:    time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
		Content: "test",
		PublishedPhotos: []*model.Photo{
			{
				ImageFilename: "photo1.jpg",
				PostSlug:      "2021-07-18-test-post",
				Desc:          "A beautiful view",
				IsGallery:     true,
				TagSlugs:      []string{"good"},
				Exif: &model.ExifData{
					ISO:         &iso,
					FocalLength: &focal,
					Aperture:    &aperture,
					Lat:         &lat,
					Lon:         &lon,
				},
			},
		},
	}
}

func renderTestMarkdown(md string, post *model.Post, lookup PostLookup) string {
	ctx := &RenderContext{
		Post:       post,
		PostLookup: lookup,
		URLBuilder: &mockURLBuilder{},
	}
	html, err := RenderPost(md, ctx)
	if err != nil {
		panic(err)
	}
	return html
}

func TestRenderPhotoNode(t *testing.T) {
	post := testPost()
	html := renderTestMarkdown(`Some text

{% photo "photo1.jpg","A beautiful view" %}

More text`, post, &mockPostLookup{})

	checks := []string{
		`<figure class="figure post-article-photo">`,
		`/images/2021-07-18-test-post/photo1.jpg`,       // full-size link
		`2021-07-18-test-post_photo1.jpg_article.jpg`,   // article JPEG
		`2021-07-18-test-post_photo1.jpg_article.avif`,  // article AVIF
		`2021-07-18-test-post_photo1.jpg_grid.jpg 560w`, // grid srcset
		`A beautiful view`,                              // caption
		`50mm`,                                          // EXIF focal length
		`f4`,                                            // EXIF aperture (no slash, matching Crystal)
		`ISO400`,                                        // EXIF ISO
		`data-is-gallery="true"`,                        // gallery flag
		`data-lat="52.450000"`,                          // GPS lat
		`/galeria/tag/good.html`,                        // photo tag gallery link
	}

	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("HTML missing %q", check)
		}
	}
}

func TestRenderPhotoNotFound(t *testing.T) {
	post := testPost()
	html := renderTestMarkdown(`{% photo "missing.jpg","caption" %}`, post, &mockPostLookup{})

	// Should not crash, just skip the photo
	if strings.Contains(html, "<figure") {
		t.Error("should not render figure for missing photo")
	}
}

func TestRenderPostURL(t *testing.T) {
	post := testPost()
	targetPost := &model.Post{
		Slug: "2021-06-03-target-post",
		Date: time.Date(2021, 6, 3, 0, 0, 0, 0, time.UTC),
	}
	lookup := &mockPostLookup{posts: map[string]*model.Post{
		"2021-06-03-target-post": targetPost,
	}}

	html := renderTestMarkdown(
		`See [here]({% post_url 2021-06-03-target-post %}).`,
		post, lookup,
	)

	// The tag inside a markdown link destination must resolve to a real
	// anchor. A CommonMark link destination cannot contain spaces, so the
	// tag has to be substituted for the URL *before* markdown parsing —
	// otherwise goldmark leaves the literal `[here](…)` brackets in place.
	if !strings.Contains(html, `<a href="/2021/06/03-target-post.html">here</a>`) {
		t.Errorf("post_url in a link should render an anchor, got: %s", html)
	}
	if strings.Contains(html, "[here]") {
		t.Errorf("literal markdown brackets leaked into output: %s", html)
	}
}

func TestRenderPostURLInParenthesizedLink(t *testing.T) {
	// The real-world shape used across the blog: a link wrapped in outer
	// parentheses, e.g. "(… ([label]({% post_url slug %})).".
	targetPost := &model.Post{
		Slug: "2020-10-10-kolejowe-roztocze-i-okolice-przemysla",
		Date: time.Date(2020, 10, 10, 0, 0, 0, 0, time.UTC),
	}
	lookup := &mockPostLookup{posts: map[string]*model.Post{
		targetPost.Slug: targetPost,
	}}

	html := renderTestMarkdown(
		`Dalej ([osobny wpis]({% post_url 2020-10-10-kolejowe-roztocze-i-okolice-przemysla %})).`,
		testPost(), lookup,
	)

	want := `<a href="/2020/10/10-kolejowe-roztocze-i-okolice-przemysla.html">osobny wpis</a>`
	if !strings.Contains(html, want) {
		t.Errorf("expected anchor %q, got: %s", want, html)
	}
	if strings.Contains(html, "[osobny wpis]") {
		t.Errorf("literal brackets leaked into output: %s", html)
	}
}

// mockLinkResolver implements LinkResolver for testing land_path/tag_path.
type mockLinkResolver struct {
	lands map[string]string
	tags  map[string]string
}

func (m mockLinkResolver) LandURL(slug string) (string, bool) { u, ok := m.lands[slug]; return u, ok }
func (m mockLinkResolver) TagURL(slug string) (string, bool)  { u, ok := m.tags[slug]; return u, ok }

func TestRenderLandPath(t *testing.T) {
	ctx := &RenderContext{
		Post:       testPost(),
		PostLookup: &mockPostLookup{},
		URLBuilder: &mockURLBuilder{},
		Links:      mockLinkResolver{lands: map[string]string{"rudawy_janowickie": "/region/rudawy_janowickie.html"}},
	}
	html, err := RenderPost(`W [Rudawach]({% land_path rudawy_janowickie %}) było zimno.`, ctx)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(html, `<a href="/region/rudawy_janowickie.html">Rudawach</a>`) {
		t.Errorf("land_path should render an anchor, got: %s", html)
	}
}

func TestRenderTagPath(t *testing.T) {
	ctx := &RenderContext{
		Post:       testPost(),
		PostLookup: &mockPostLookup{},
		URLBuilder: &mockURLBuilder{},
		Links:      mockLinkResolver{tags: map[string]string{"main": "/tag/glowne.html"}},
	}
	html, err := RenderPost(`zobacz [wszystkie]({% tag_path main %}).`, ctx)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(html, `<a href="/tag/glowne.html">wszystkie</a>`) {
		t.Errorf("tag_path should render an anchor, got: %s", html)
	}
}

func TestRenderLandPathNotFound(t *testing.T) {
	ctx := &RenderContext{
		Post:       testPost(),
		PostLookup: &mockPostLookup{},
		URLBuilder: &mockURLBuilder{},
		Links:      mockLinkResolver{},
	}
	html, err := RenderPost(`[x]({% land_path nieznany %})`, ctx)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(html, "#land-not-found") {
		t.Errorf("unknown land should fall back to sentinel, got: %s", html)
	}
}

func TestRenderPostURLNotFound(t *testing.T) {
	post := testPost()
	html := renderTestMarkdown(
		`See [here]({% post_url missing-post %}).`,
		post, &mockPostLookup{posts: map[string]*model.Post{}},
	)

	if !strings.Contains(html, "#post-not-found") {
		t.Errorf("HTML should contain fallback, got: %s", html)
	}
}

func TestRenderGeo(t *testing.T) {
	post := testPost()
	html := renderTestMarkdown(
		`Location: {% geo 52.45,16.93 %}`,
		post, &mockPostLookup{},
	)

	if !strings.Contains(html, "openstreetmap.org") {
		t.Error("HTML should contain OSM link")
	}
	if !strings.Contains(html, "google.com/maps") {
		t.Error("HTML should contain Google Maps link")
	}
}

func TestRenderProTip(t *testing.T) {
	post := testPost()
	html := renderTestMarkdown(
		`{% pro_tip %} Pack water.`,
		post, &mockPostLookup{},
	)

	if !strings.Contains(html, `<span class="pro-tip">Porada:</span>`) {
		t.Errorf("HTML should contain pro tip span, got: %s", html)
	}
}

func TestRenderCurrentYear(t *testing.T) {
	post := testPost()
	html := renderTestMarkdown(
		`Copyright {% current_year %}.`,
		post, &mockPostLookup{},
	)

	if !strings.Contains(html, "202") {
		t.Errorf("HTML should contain current year, got: %s", html)
	}
}

func TestRenderTodo(t *testing.T) {
	post := testPost()
	html := renderTestMarkdown(
		`Some text {% todo %} more.`,
		post, &mockPostLookup{},
	)

	// Todo should produce no visible output
	if strings.Contains(html, "todo") {
		t.Errorf("HTML should not contain 'todo', got: %s", html)
	}
}

func TestRenderPhotoHeader(t *testing.T) {
	post := testPost()
	html := renderTestMarkdown(
		`{% photo_header "Header caption","tag:best" %}

Some text`,
		post, &mockPostLookup{},
	)

	// PhotoHeader should produce no visible output
	if strings.Contains(html, "Header caption") {
		t.Errorf("HTML should not contain photo_header content, got: %s", html)
	}
}

func TestRenderStandardMarkdown(t *testing.T) {
	post := testPost()
	html := renderTestMarkdown(`# Hello

This is **bold** and *italic*.

- Item 1
- Item 2`, post, &mockPostLookup{})

	checks := []string{
		"<h1>Hello</h1>",
		"<strong>bold</strong>",
		"<em>italic</em>",
		"<li>Item 1</li>",
	}

	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("HTML missing %q", check)
		}
	}
}
