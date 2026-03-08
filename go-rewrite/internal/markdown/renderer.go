package markdown

import (
	"bytes"
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/renderer"
	"github.com/yuin/goldmark/renderer/html"
	"github.com/yuin/goldmark/text"
	"github.com/yuin/goldmark/util"

	"odkrywajac/internal/model"
	"odkrywajac/internal/templates/components"
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

// RenderContext holds all dependencies needed for rendering markdown.
type RenderContext struct {
	Post          *model.Post
	PostLookup    PostLookup
	URLBuilder    PostURLBuilder
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

	// Build photo tag gallery links
	for _, tagSlug := range photo.TagSlugs {
		link := components.PhotoTagLink{
			URL:  ub.TagGalleryURL(&model.Tag{SlugPl: tagSlug}),
			Icon: tagSlug,
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

	post := r.ctx.PostLookup.PostBySlug(n.PostSlug)
	if post != nil {
		w.WriteString(r.ctx.URLBuilder.PostURL(post))
	} else {
		slog.Warn("Cross-referenced post not found", "slug", n.PostSlug)
		w.WriteString("#post-not-found")
	}

	return ast.WalkContinue, nil
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
	src := []byte(content)
	reader := text.NewReader(src)
	doc := md.Parser().Parse(reader)

	if err := md.Renderer().Render(&buf, src, doc); err != nil {
		return "", fmt.Errorf("render markdown: %w", err)
	}

	return buf.String(), nil
}
