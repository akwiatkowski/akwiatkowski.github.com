package bundle

import (
	"os"
	"path/filepath"
	"testing"
)

func testConfigPath(t *testing.T) string {
	t.Helper()
	// Find the project config
	// Walk up to find go-rewrite/config/asset_bundles.yml
	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for {
		candidate := filepath.Join(dir, "config", "asset_bundles.yml")
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	t.Skip("asset_bundles.yml not found")
	return ""
}

func TestNewResolver(t *testing.T) {
	r, err := NewResolver(testConfigPath(t))
	if err != nil {
		t.Fatal(err)
	}
	names := r.BundleNames()
	if len(names) < 10 {
		t.Errorf("expected at least 10 bundles, got %d", len(names))
	}
}

func TestResolveAtomicBundle(t *testing.T) {
	r, err := NewResolver(testConfigPath(t))
	if err != nil {
		t.Fatal(err)
	}

	files := r.Resolve([]string{"bootstrap-css"})
	if len(files) != 1 {
		t.Fatalf("expected 1 file, got %d", len(files))
	}
	if files[0].Path != "/css/libs/bootstrap.min.css" {
		t.Errorf("unexpected path: %s", files[0].Path)
	}
	if !files[0].IsCSS {
		t.Error("expected CSS file")
	}
}

func TestResolveComposite(t *testing.T) {
	r, err := NewResolver(testConfigPath(t))
	if err != nil {
		t.Fatal(err)
	}

	files := r.Resolve([]string{"core"})
	if len(files) < 4 {
		t.Errorf("expected at least 4 files from core, got %d", len(files))
	}

	// CSS should come before JS
	firstJS := -1
	lastCSS := -1
	for i, f := range files {
		if f.IsCSS {
			lastCSS = i
		} else if firstJS == -1 {
			firstJS = i
		}
	}
	if firstJS != -1 && lastCSS != -1 && lastCSS > firstJS {
		t.Error("CSS files should come before JS files")
	}
}

func TestResolveDedup(t *testing.T) {
	r, err := NewResolver(testConfigPath(t))
	if err != nil {
		t.Fatal(err)
	}

	// Request core twice — should not duplicate
	files := r.Resolve([]string{"core", "core"})
	seen := make(map[string]bool)
	for _, f := range files {
		if seen[f.Path] {
			t.Errorf("duplicate file: %s", f.Path)
		}
		seen[f.Path] = true
	}
}

func TestResolveMultipleBundles(t *testing.T) {
	r, err := NewResolver(testConfigPath(t))
	if err != nil {
		t.Fatal(err)
	}

	files := r.Resolve([]string{"core", "leaflet"})
	hasLeafletCSS := false
	hasLeafletJS := false
	hasBootstrapCSS := false
	for _, f := range files {
		switch f.Path {
		case "/css/libs/leaflet.css":
			hasLeafletCSS = true
		case "/js/libs/leaflet.js":
			hasLeafletJS = true
		case "/css/libs/bootstrap.min.css":
			hasBootstrapCSS = true
		}
	}
	if !hasLeafletCSS {
		t.Error("missing leaflet CSS")
	}
	if !hasLeafletJS {
		t.Error("missing leaflet JS")
	}
	if !hasBootstrapCSS {
		t.Error("missing bootstrap CSS")
	}
}

func TestIntegrity(t *testing.T) {
	r, err := NewResolver(testConfigPath(t))
	if err != nil {
		t.Fatal(err)
	}

	files := r.Resolve([]string{"leaflet"})
	for _, f := range files {
		if f.Path == "/js/libs/leaflet.js" {
			if f.Integrity == "" {
				t.Error("leaflet.js should have integrity hash")
			}
			return
		}
	}
	t.Error("leaflet.js not found in resolved files")
}

func TestResolvePageAssets(t *testing.T) {
	r, err := NewResolver(testConfigPath(t))
	if err != nil {
		t.Fatal(err)
	}

	files := r.ResolvePageAssets([]string{"gallery"})
	if len(files) != 2 {
		t.Fatalf("expected 2 gallery CSS files, got %d", len(files))
	}
	if files[0].Path != "/css/self/new_gallery.css" {
		t.Errorf("unexpected first gallery file: %s", files[0].Path)
	}
}
