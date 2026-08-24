package content

import (
	"fmt"
	"log/slog"
	"regexp"
	"strings"
	"time"
)

// Canonicalizer turns a site-relative path into an absolute URL. The Markdown
// representation of a post is consumed out of band (an LLM is handed the text
// with no base URL), so every link it contains has to be absolute — unlike the
// HTML rendering, where site-relative paths resolve against the current page.
// *router.Router satisfies this.
type Canonicalizer interface {
	CanonicalURL(path string) string
}

// directiveRe matches any `{% … %}` blog directive. The Markdown rendering
// substitutes directives in the source text rather than walking the goldmark
// AST: the source is already CommonMark, so the directives are the only part
// that is not. Re-emitting the whole AST as Markdown would mean reimplementing
// a renderer for every CommonMark node just to get back what we started with,
// and would silently normalize the author's formatting along the way.
//
// The inner group is non-greedy and excludes `%` so adjacent directives on one
// line do not merge into a single match.
var directiveRe = regexp.MustCompile(`\{%\s*([^%]+?)\s*%\}`)

// blankLinesRe matches three or more consecutive newlines, i.e. a run of blank
// lines left behind when a block directive renders to nothing.
var blankLinesRe = regexp.MustCompile(`\n{3,}`)

// RenderPostMarkdown renders a post's source content to clean CommonMark for
// the `.md` representation served to LLMs and AI agents.
//
// It mirrors RenderPost's directive semantics — same nodes, same skip rules —
// but emits Markdown instead of HTML: photos become image links, geo
// coordinates become an OpenStreetMap link, and output-less directives
// (photo_header, todo) vanish. Unknown directives are dropped with a warning
// rather than passed through, so template syntax never leaks into the output.
//
// Unlike RenderPost this cannot fail: there is no goldmark render step, only
// string substitution, so it returns no error.
func RenderPostMarkdown(source string, ctx *RenderContext) string {
	expanded := directiveRe.ReplaceAllStringFunc(source, func(match string) string {
		inner := strings.TrimSpace(directiveRe.FindStringSubmatch(match)[1])
		return renderDirectiveMarkdown(inner, ctx)
	})

	// Dropped block directives leave runs of blank lines behind; collapse them
	// so the output does not accumulate vertical gaps.
	expanded = blankLinesRe.ReplaceAllString(expanded, "\n\n")
	return strings.TrimSpace(expanded)
}

// renderDirectiveMarkdown expands a single directive body (the text between
// `{%` and `%}`) into its Markdown form, or "" for directives that produce no
// output.
func renderDirectiveMarkdown(inner string, ctx *RenderContext) string {
	switch {
	case strings.HasPrefix(inner, "photo_header"):
		// Header photo is page chrome, not article content — same as HTML.
		return ""

	case strings.HasPrefix(inner, "photo "):
		filename, caption, _ := parsePhotoArgs(inner[len("photo "):])
		return photoMarkdown(filename, caption, ctx)

	case strings.HasPrefix(inner, "post_url "):
		slug := strings.TrimSpace(inner[len("post_url "):])
		return absoluteURL(resolvePostURL(ctx, slug), ctx)

	case strings.HasPrefix(inner, "land_path "):
		slug := strings.TrimSpace(inner[len("land_path "):])
		if ctx.Links != nil {
			if url, ok := ctx.Links.LandURL(slug); ok {
				return absoluteURL(url, ctx)
			}
		}
		slog.Warn("markdown: land_path region not found", "slug", slug)
		return ""

	case strings.HasPrefix(inner, "tag_path "):
		slug := strings.TrimSpace(inner[len("tag_path "):])
		if ctx.Links != nil {
			if url, ok := ctx.Links.TagURL(slug); ok {
				return absoluteURL(url, ctx)
			}
		}
		slog.Warn("markdown: tag_path tag not found", "slug", slug)
		return ""

	case strings.HasPrefix(inner, "geo "):
		lat, lon, ok := parseGeoArgs(strings.TrimSpace(inner[len("geo "):]))
		if !ok {
			return ""
		}
		return fmt.Sprintf("[%.5f, %.5f](https://www.openstreetmap.org/?mlat=%f&mlon=%f#map=14/%f/%f)",
			lat, lon, lat, lon, lat, lon)

	case inner == "pro_tip":
		return "**Porada:**"

	case inner == "current_year":
		return fmt.Sprintf("%d", time.Now().Year())

	case inner == "todo":
		return ""
	}

	slog.Warn("markdown: unknown directive dropped", "directive", inner)
	return ""
}

// photoMarkdown renders a {% photo %} directive as a CommonMark image.
//
// The photo is looked up through PublishedPhotoByFilename so unpublished
// photos are skipped exactly as they are in HTML, and the caption comes from
// the resolved photo (photo.Desc) rather than the directive argument, matching
// renderPhoto. The image points at the `article` JPEG: AVIF and the responsive
// srcset have no CommonMark equivalent, and JPEG is the universally decodable
// choice for a consumer fetching the Markdown.
func photoMarkdown(filename, caption string, ctx *RenderContext) string {
	post := ctx.Post
	photo := post.PublishedPhotoByFilename(filename)
	if photo == nil {
		slog.Warn("markdown: photo not found in post", "file", filename, "post", post.Slug)
		return ""
	}

	if photo.Desc != "" {
		caption = photo.Desc
	}

	url := absoluteURL(ctx.URLBuilder.ProcessedImageURL(post, photo.ImageFilename, "article", "jpg"), ctx)
	return fmt.Sprintf("![%s](%s)", escapeMarkdownAlt(caption), url)
}

// absoluteURL promotes a site-relative path to a full URL when a Canonicalizer
// is available. Already-absolute URLs (external links) and empty paths pass
// through untouched.
func absoluteURL(path string, ctx *RenderContext) string {
	if path == "" || ctx.Canonical == nil || strings.Contains(path, "://") {
		return path
	}
	return ctx.Canonical.CanonicalURL(path)
}

// escapeMarkdownAlt escapes the two characters that would terminate an image's
// alt text early. Captions are Polish prose and rarely contain either, but a
// stray bracket would otherwise corrupt the link syntax.
func escapeMarkdownAlt(s string) string {
	s = strings.ReplaceAll(s, `[`, `\[`)
	return strings.ReplaceAll(s, `]`, `\]`)
}
