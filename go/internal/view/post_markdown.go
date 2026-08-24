package view

import (
	"fmt"
	"io"
	"strings"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/content"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
)

// PostMarkdownPage creates a Renderable serving a post as clean CommonMark at
// /<year>/<month>/<day>-<slug>.md.
//
// This is the Markdown alternate advertised to LLMs and AI agents: the same
// content as the HTML article, without navigation, asset bundles, or markup
// noise. It is generated from the same source through the same directive
// semantics as the HTML (see content.RenderPostMarkdown), so the two cannot
// drift apart — there is one content store, rendered twice.
//
// The endpoint stays out of the sitemap: sitemaps index pages for search
// engines, and listing both representations of every post would duplicate the
// entire corpus. Discovery happens through llms.txt and the page's
// <link rel="alternate"> instead.
func PostMarkdownPage(
	data *catalog.SiteData,
	post *model.Post,
	r *router.Router,
) Renderable {
	return NewRawEndpoint(r.PostMarkdownURL(post), false, func(w io.Writer) error {
		renderCtx := &content.RenderContext{
			Post:       post,
			PostLookup: data,
			URLBuilder: r,
			TagLookup:  data,
			Links:      linkResolver{data: data, router: r},
			Canonical:  r,
		}

		body := content.RenderPostMarkdown(post.Content, renderCtx)
		_, err := io.WriteString(w, postMarkdownDocument(post, body, r))
		return err
	})
}

// postMarkdownDocument wraps a rendered post body in a small Markdown header:
// title, subtitle, date/author byline, and a link back to the HTML page.
//
// The header exists because the Markdown file is read out of context — a model
// handed the raw text has no page title, no <h1>, and no URL to attribute the
// content to. The back-link is the counterpart of the page's
// <link rel="alternate">: a consumer landing on either representation can find
// the other.
func postMarkdownDocument(post *model.Post, body string, r *router.Router) string {
	var b strings.Builder

	fmt.Fprintf(&b, "# %s\n\n", post.Title)
	if post.Subtitle != "" {
		fmt.Fprintf(&b, "> %s\n\n", post.Subtitle)
	}

	byline := post.Date.Format("2006-01-02")
	if post.Author != "" {
		byline += " · " + post.Author
	}
	fmt.Fprintf(&b, "*%s*\n\n", byline)

	fmt.Fprintf(&b, "[Wersja HTML](%s)\n\n---\n\n", r.CanonicalURL(r.PostURL(post)))

	b.WriteString(body)
	b.WriteString("\n")
	return b.String()
}
