package render

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNewManifest(t *testing.T) {
	m := NewManifest("dev", "go")
	if m.Env != "dev" || m.Target != "go" {
		t.Errorf("unexpected env=%q target=%q", m.Env, m.Target)
	}
	if m.Len() != 0 {
		t.Errorf("new manifest should be empty, got %d entries", m.Len())
	}
}

func TestManifestSetGet(t *testing.T) {
	m := NewManifest("dev", "go")
	m.Set("/page.html", ManifestEntry{SHA256: "abc123", Size: 100})

	e, ok := m.Get("/page.html")
	if !ok {
		t.Fatal("entry not found")
	}
	if e.SHA256 != "abc123" || e.Size != 100 {
		t.Errorf("unexpected entry: %+v", e)
	}

	_, ok = m.Get("/missing.html")
	if ok {
		t.Error("should not find missing entry")
	}
}

func TestManifestSaveLoad(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "manifest.json")

	// Save
	m := NewManifest("dev", "go")
	m.Set("/page.html", ManifestEntry{SHA256: "abc123", Size: 100})
	if err := m.Save(path); err != nil {
		t.Fatal(err)
	}

	// Load
	m2 := LoadManifest(path, "dev", "go")
	if m2.Len() != 1 {
		t.Fatalf("expected 1 entry, got %d", m2.Len())
	}
	e, ok := m2.Get("/page.html")
	if !ok || e.SHA256 != "abc123" {
		t.Errorf("loaded entry = %+v", e)
	}
}

func TestLoadManifestMissing(t *testing.T) {
	m := LoadManifest("/nonexistent/path.json", "dev", "go")
	if m.Len() != 0 {
		t.Error("missing file should return empty manifest")
	}
}

func TestLoadManifestCorrupt(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "manifest.json")
	os.WriteFile(path, []byte("not json"), 0o644)

	m := LoadManifest(path, "dev", "go")
	if m.Len() != 0 {
		t.Error("corrupt file should return empty manifest")
	}
}
