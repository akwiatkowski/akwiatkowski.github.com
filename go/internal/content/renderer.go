package content

import (
	"bytes"
	"context"
	"fmt"
	"log/slog"
	"regexp"
	"time"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/renderer"
	"github.com/yuin/goldmark/renderer/html"
	"github.com/yuin/goldmark/text"
	"github.com/yuin/goldmark/util"

	"odkrywajac/internal/model"
	"odkrywajac/internal/view/template/components"
)

// PostLookup provides post resolution for {% post_url %} directives.
type PostLookup interface {
	PostBySlug(slug string) *model.Post
}

// PostURLBuilder generates URLs for posts.
type PostURLBuilder interface {
	PostURL(post *model.Post) string
	ProcessedImageURL(post *model.Post, filename, size, format string) string
	PostImageURL(post *model.Post, filename string) string
	TagGalleryURL(tag *model.Tag) string
}

// TagLookup provides photo tag resolution.
type TagLookup interface {
	PhotoTagBySlug(slug string) *model.PhotoTag
}

// LinkResolver resolves a land (region) or content-tag slug to its site URL for
// the {% land_path %} and {% tag_path %} directives. The bool is false when no
// such area/tag exists, so hardcoded legacy URLs are replaced by slug-safe,
// engine-generated links instead. Implemented in the view layer (it needs both
// the site data and the router), kept as an interface here to avoid a cycle.
type LinkResolver interface {
	LandURL(slug string) (string, bool)
	TagURL(slug string) (string, bool)
}

// RenderContext holds all dependencies needed for rendering markdown.
type RenderContext struct {
	Post          *model.Post
	PostLookup    PostLookup
	URLBuilder    PostURLBuilder
	TagLookup     TagLookup
	Links         LinkResolver
	PhotoTagIcons map[string]string // photo tag slug → icon name
}

// customRenderer renders custom AST nodes to HTML.
type customRenderer struct {
	ctx *RenderContext
}

func (r *customRenderer) RegisterFuncs(reg renderer.NodeRendererFuncRegisterer) {
	reg.Register(KindPhoto, r.renderPhoto)
	reg.Register(KindPhotoHeader, r.renderPhotoHeader)
	reg.Register(KindPostURL, r.renderPostURL)
	reg.Register(KindGeo, r.renderGeo)
	reg.Register(KindProTip, r.renderProTip)
	reg.Register(KindCurrentYear, r.renderCurrentYear)
	reg.Register(KindTodo, r.renderTodo)
}

func (r *customRenderer) renderPhoto(w util.BufWriter, source []byte, node ast.Node, entering bool) (ast.WalkStatus, error) {
	if !entering {
		return ast.WalkContinue, nil
	}
	n := node.(*PhotoNode)

	post := r.ctx.Post
	photo := post.PublishedPhotoByFilename(n.Filename)
	if photo == nil {
		slog.Warn("Photo not found in post", "file", n.Filename, "post", post.Slug)
		return ast.WalkContinue, nil
	}

	ub := r.ctx.URLBuilder
	data := components.ArticlePhotoData{
		FullSizeURL: ub.PostImageURL(post, photo.ImageFilename),
		ArticleJPEG: ub.ProcessedImageURL(post, photo.ImageFilename, "article", "jpg"),
		ArticleAVIF: ub.ProcessedImageURL(post, photo.ImageFilename, "article", "avif"),
		GridJPEG:    ub.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg"),
		GridAVIF:    ub.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif"),
		Caption:     photo.Desc,
		ExifString:  photo.ExifString(),
		IsGallery:   photo.IsGallery,
		IsTimeline:  photo.IsTimeline,
		HasGPS:      photo.HasGPS(),
		HasTime:     photo.HasTime(),
	}

	if photo.HasGPS() {
		data.Lat = *photo.Exif.Lat
		data.Lon = *photo.Exif.Lon
		if photo.Exif.Altitude != nil {
			data.Altitude = *photo.Exif.Altitude
		}
	}
	if photo.HasTime() {
		data.TimeStr = photo.Exif.Time.Format(time.RFC3339)
	}

	// Build photo tag gallery links with Bootstrap Icons.
	// Only render tags that have a known icon mapping (matching Crystal behavior).
	for _, tagSlug := range photo.TagSlugs {
		iconName := components.ResolveBootstrapIcon(tagSlug)
		if iconName == "" {
			continue
		}
		slugPl := tagSlug // fallback to English slug
		if r.ctx.TagLookup != nil {
			if pt := r.ctx.TagLookup.PhotoTagBySlug(tagSlug); pt != nil {
				slugPl = pt.SlugPl
			}
		}
		link := components.PhotoTagLink{
			URL:  ub.TagGalleryURL(&model.Tag{SlugPl: slugPl}),
			Icon: iconName,
		}
		data.TagLinks = append(data.TagLinks, link)
	}

	var buf bytes.Buffer
	if err := components.ArticlePhoto(data).Render(context.Background(), &buf); err != nil {
		return ast.WalkContinue, err
	}
	w.Write(buf.Bytes())

	return ast.WalkContinue, nil
}

func (r *customRenderer) renderPhotoHeader(w util.BufWriter, source []byte, node ast.Node, entering bool) (ast.WalkStatus, error) {
	// PhotoHeader produces no output — metadata was handled in Phase 2
	return ast.WalkContinue, nil
}

func (r *customRenderer) renderPostURL(w util.BufWriter, source []byte, node ast.Node, entering bool) (ast.WalkStatus, error) {
	if !entering {
		return ast.WalkContinue, nil
	}
	n := node.(*PostURLNode)
	w.WriteString(resolvePostURL(r.ctx, n.PostSlug))
	return ast.WalkContinue, nil
}

// linkTagRe matches the link directives that resolve to a site URL:
// `{% post_url <slug> %}`, `{% land_path <slug> %}`, `{% tag_path <slug> %}`.
// The slug is a run of non-space, non-`%` characters (slugs never contain either).
var linkTagRe = regexp.MustCompile(`\{%\s*(post_url|land_path|tag_path)\s+([^\s%]+)\s*%\}`)

// resolvePostURL turns a post slug into its site URL, or the `#post-not-found`
// sentinel (with a warning) when no such post exists.
func resolvePostURL(ctx *RenderContext, slug string) string {
	if post := ctx.PostLookup.PostBySlug(slug); post != nil {
		return ctx.URLBuilder.PostURL(post)
	}
	slog.Warn("Cross-referenced post not found", "slug", slug)
	return "#post-not-found"
}

// resolveLinkTags substitutes every link directive with its resolved URL
// *before* markdown parsing. This is required — not just an optimization —
// because a CommonMark link destination cannot contain spaces, so the tag has
// to already be a bare URL by the time goldmark parses `[label](URL)`. Leaving
// it as a tag makes goldmark reject the link and emit literal `[label](…)`
// brackets. Mirrors how the Crystal engine expands such tags pre-markdown.
func resolveLinkTags(content string, ctx *RenderContext) string {
	return linkTagRe.ReplaceAllStringFunc(content, func(match string) string {
		m := linkTagRe.FindStringSubmatch(match)
		directive, slug := m[1], m[2]
		switch directive {
		case "post_url":
			return resolvePostURL(ctx, slug)
		case "land_path":
			if ctx.Links != nil {
				if url, ok := ctx.Links.LandURL(slug); ok {
					return url
				}
			}
			slog.Warn("land_path: region not found", "slug", slug)
			return "#land-not-found"
		case "tag_path":
			if ctx.Links != nil {
				if url, ok := ctx.Links.TagURL(slug); ok {
					return url
				}
			}
			slog.Warn("tag_path: tag not found", "slug", slug)
			return "#tag-not-found"
		}
		return match
	})
}

func (r *customRenderer) renderGeo(w util.BufWriter, source []byte, node ast.Node, entering bool) (ast.WalkStatus, error) {
	if !entering {
		return ast.WalkContinue, nil
	}
	n := node.(*GeoNode)

	var buf bytes.Buffer
	if err := components.GeoLinks(n.Lat, n.Lon).Render(context.Background(), &buf); err != nil {
		return ast.WalkContinue, err
	}
	w.Write(buf.Bytes())

	return ast.WalkContinue, nil
}

func (r *customRenderer) renderProTip(w util.BufWriter, source []byte, node ast.Node, entering bool) (ast.WalkStatus, error) {
	if !entering {
		return ast.WalkContinue, nil
	}
	w.WriteString(`<span class="pro-tip">Porada:</span>`)
	return ast.WalkContinue, nil
}

func (r *customRenderer) renderCurrentYear(w util.BufWriter, source []byte, node ast.Node, entering bool) (ast.WalkStatus, error) {
	if !entering {
		return ast.WalkContinue, nil
	}
	w.WriteString(fmt.Sprintf("%d", time.Now().Year()))
	return ast.WalkContinue, nil
}

func (r *customRenderer) renderTodo(w util.BufWriter, source []byte, node ast.Node, entering bool) (ast.WalkStatus, error) {
	// Todo produces no output
	return ast.WalkContinue, nil
}

// RenderPost renders a post's markdown content to HTML using goldmark with custom extensions.
func RenderPost(content string, ctx *RenderContext) (string, error) {
	md := goldmark.New(
		goldmark.WithExtensions(&Extension{}),
		goldmark.WithRendererOptions(
			html.WithUnsafe(),
			renderer.WithNodeRenderers(
				util.Prioritized(&customRenderer{ctx: ctx}, 50),
			),
		),
	)

	var buf bytes.Buffer
	src := []byte(resolveLinkTags(content, ctx))
	reader := text.NewReader(src)
	doc := md.Parser().Parse(reader)

	if err := md.Renderer().Render(&buf, src, doc); err != nil {
		return "", fmt.Errorf("render markdown: %w", err)
	}

	return buf.String(), nil
}
