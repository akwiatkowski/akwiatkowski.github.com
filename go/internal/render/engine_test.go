package render

import (
	"fmt"
	"io"
	"testing"

	"odkrywajac/internal/view"
)

// mockView implements view.Renderable for testing.
type mockView struct {
	url     string
	content string
	sitemap bool
}

func (m *mockView) URL() string        { return m.url }
func (m *mockView) AddToSitemap() bool { return m.sitemap }
func (m *mockView) Render(w io.Writer) error {
	_, err := fmt.Fprint(w, m.content)
	return err
}

type failView struct {
	url string
}

func (f *failView) URL() string        { return f.url }
func (f *failView) AddToSitemap() bool { return false }
func (f *failView) Render(w io.Writer) error {
	return fmt.Errorf("render failed")
}

func TestRender_BasicViews(t *testing.T) {
	dir := t.TempDir()
	manifest := NewManifest("dev", "go")

	views := []view.Renderable{
		&mockView{url: "/page1.html", content: "<!doctype html><html><head><title>P1</title></head><body>1</body></html>"},
		&mockView{url: "/page2.html", content: "<!doctype html><html><head><title>P2</title></head><body>2</body></html>"},
		&mockView{url: "/data.json", content: `{"ok":true}`},
	}

	result := Render(views, dir, manifest, 2)

	if result.TotalViews != 3 {
		t.Errorf("TotalViews = %d, want 3", result.TotalViews)
	}
	if result.Written != 3 {
		t.Errorf("Written = %d, want 3", result.Written)
	}
	if len(result.Errors) > 0 {
		t.Errorf("unexpected errors: %v", result.Errors)
	}
}

func TestRender_SecondRunSkips(t *testing.T) {
	dir := t.TempDir()
	manifest := NewManifest("dev", "go")

	views := []view.Renderable{
		&mockView{url: "/page.html", content: "<!doctype html><html><head><title>T</title></head><body>ok</body></html>"},
	}

	// First run
	result1 := Render(views, dir, manifest, 1)
	if result1.Written != 1 {
		t.Fatalf("first run: written=%d", result1.Written)
	}

	// Second run with same content — should skip
	result2 := Render(views, dir, manifest, 1)
	if result2.Skipped != 1 {
		t.Errorf("second run: skipped=%d, want 1", result2.Skipped)
	}
	if result2.Written != 0 {
		t.Errorf("second run: written=%d, want 0", result2.Written)
	}
}

func TestRender_CollectsErrors(t *testing.T) {
	dir := t.TempDir()
	manifest := NewManifest("dev", "go")

	views := []view.Renderable{
		&failView{url: "/fail.html"},
		&mockView{url: "/ok.html", content: "<!doctype html><html><head><title>OK</title></head><body>ok</body></html>"},
	}

	result := Render(views, dir, manifest, 1)
	if len(result.Errors) != 1 {
		t.Errorf("expected 1 error, got %d: %v", len(result.Errors), result.Errors)
	}
	if result.Written != 1 {
		t.Errorf("written=%d, want 1", result.Written)
	}
}

func TestRender_Validation(t *testing.T) {
	dir := t.TempDir()
	manifest := NewManifest("dev", "go")

	views := []view.Renderable{
		&mockView{url: "/bad.html", content: `<!doctype html><html><head></head><body></body></html>`},
	}

	result := Render(views, dir, manifest, 1)
	if len(result.ValErrors) == 0 {
		t.Error("expected validation errors for missing title")
	}
}
