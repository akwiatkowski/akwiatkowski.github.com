package render

import (
	"os"
	"path/filepath"
	"testing"
)

func TestWriter_WriteNewFile(t *testing.T) {
	dir := t.TempDir()
	m := NewManifest("dev", "go")
	w := NewWriter(dir, m)

	err := w.Write(OutputFile{URL: "/page.html", Content: []byte("<html></html>")})
	if err != nil {
		t.Fatal(err)
	}

	// Check file was written
	data, err := os.ReadFile(filepath.Join(dir, "page.html"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "<html></html>" {
		t.Errorf("unexpected content: %q", string(data))
	}

	// Check stats
	written, skipped := w.Stats()
	if written != 1 || skipped != 0 {
		t.Errorf("expected 1 written 0 skipped, got %d/%d", written, skipped)
	}
}

func TestWriter_SkipUnchanged(t *testing.T) {
	dir := t.TempDir()
	m := NewManifest("dev", "go")
	w := NewWriter(dir, m)

	content := []byte("<html>test</html>")
	w.Write(OutputFile{URL: "/page.html", Content: content})
	w.Write(OutputFile{URL: "/page.html", Content: content}) // same content

	written, skipped := w.Stats()
	if written != 1 || skipped != 1 {
		t.Errorf("expected 1 written 1 skipped, got %d/%d", written, skipped)
	}
}

func TestWriter_WriteChanged(t *testing.T) {
	dir := t.TempDir()
	m := NewManifest("dev", "go")
	w := NewWriter(dir, m)

	w.Write(OutputFile{URL: "/page.html", Content: []byte("v1")})
	w.Write(OutputFile{URL: "/page.html", Content: []byte("v2")})

	written, skipped := w.Stats()
	if written != 2 || skipped != 0 {
		t.Errorf("expected 2 written 0 skipped, got %d/%d", written, skipped)
	}

	data, _ := os.ReadFile(filepath.Join(dir, "page.html"))
	if string(data) != "v2" {
		t.Errorf("expected v2, got %q", string(data))
	}
}

func TestWriter_CreateSubdirectories(t *testing.T) {
	dir := t.TempDir()
	m := NewManifest("dev", "go")
	w := NewWriter(dir, m)

	err := w.Write(OutputFile{URL: "/deep/nested/page.html", Content: []byte("ok")})
	if err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(filepath.Join(dir, "deep", "nested", "page.html"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "ok" {
		t.Errorf("unexpected: %q", string(data))
	}
}

func TestWriter_ManifestUpdated(t *testing.T) {
	dir := t.TempDir()
	m := NewManifest("dev", "go")
	w := NewWriter(dir, m)

	w.Write(OutputFile{URL: "/page.html", Content: []byte("content")})

	entry, ok := m.Get("/page.html")
	if !ok {
		t.Fatal("manifest entry not found")
	}
	if entry.SHA256 == "" {
		t.Error("expected non-empty SHA256")
	}
	if entry.Size != 7 {
		t.Errorf("expected size=7, got %d", entry.Size)
	}
}
