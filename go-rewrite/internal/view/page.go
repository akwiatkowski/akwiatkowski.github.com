// Package view defines the Renderable interface and concrete page types.
package view

import (
	"bytes"
	"context"
	"encoding/json"
	"io"

	"github.com/a-h/templ"

	"odkrywajac/internal/templates/components"
	"odkrywajac/internal/templates/layout"
)

// Renderable is implemented by everything that produces output.
type Renderable interface {
	URL() string
	Render(w io.Writer) error
	AddToSitemap() bool
}

// HTMLPage is a full HTML page with the standard shell (head, nav, footer).
type HTMLPage struct {
	url     string
	page    layout.PageData
	content templ.Component
	sitemap bool
}

// NewHTMLPage creates a new HTMLPage.
func NewHTMLPage(url string, page layout.PageData, content templ.Component, sitemap bool) *HTMLPage {
	return &HTMLPage{url: url, page: page, content: content, sitemap: sitemap}
}

func (h *HTMLPage) URL() string        { return h.url }
func (h *HTMLPage) AddToSitemap() bool { return h.sitemap }

func (h *HTMLPage) Render(w io.Writer) error {
	return layout.Page(h.page).Render(templ.WithChildren(context.Background(), h.content), w)
}

// JSONEndpoint produces raw JSON output (no page shell).
type JSONEndpoint struct {
	url  string
	data any
}

// NewJSONEndpoint creates a new JSONEndpoint.
func NewJSONEndpoint(url string, data any) *JSONEndpoint {
	return &JSONEndpoint{url: url, data: data}
}

func (j *JSONEndpoint) URL() string        { return j.url }
func (j *JSONEndpoint) AddToSitemap() bool { return false }

func (j *JSONEndpoint) Render(w io.Writer) error {
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	return enc.Encode(j.data)
}

// RawEndpoint produces raw content (XML, text, etc.) with a custom render function.
type RawEndpoint struct {
	url     string
	render  func(w io.Writer) error
	sitemap bool
}

// NewRawEndpoint creates a new RawEndpoint.
func NewRawEndpoint(url string, sitemap bool, render func(w io.Writer) error) *RawEndpoint {
	return &RawEndpoint{url: url, render: render, sitemap: sitemap}
}

func (r *RawEndpoint) URL() string        { return r.url }
func (r *RawEndpoint) AddToSitemap() bool { return r.sitemap }
func (r *RawEndpoint) Render(w io.Writer) error {
	return r.render(w)
}

// RedirectPage produces a minimal HTML page with a JS redirect.
type RedirectPage struct {
	url    string
	target string
	status int
}

// NewRedirectPage creates a new RedirectPage.
func NewRedirectPage(url, target string, status int) *RedirectPage {
	return &RedirectPage{url: url, target: target, status: status}
}

func (r *RedirectPage) URL() string        { return r.url }
func (r *RedirectPage) AddToSitemap() bool { return false }

func (r *RedirectPage) Render(w io.Writer) error {
	var buf bytes.Buffer
	if err := components.RedirectPage(r.target, r.status).Render(context.Background(), &buf); err != nil {
		return err
	}
	_, err := w.Write(buf.Bytes())
	return err
}
