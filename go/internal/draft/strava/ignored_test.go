package strava

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadIgnoredIDs(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "ignored_activities.yml")
	content := `# skip-list
ignored:
  - id: 12345
    name: "Commute"
    date: 2026-05-01
    reason: "commute"
    ignored_at: 2026-05-02
  - id: 67890
    name: "GPS test"
    date: 2026-05-03
    reason: "test"
    ignored_at: 2026-05-03
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	ids, err := LoadIgnoredIDs(path)
	if err != nil {
		t.Fatalf("LoadIgnoredIDs: %v", err)
	}
	if len(ids) != 2 {
		t.Fatalf("expected 2 ignored IDs, got %d", len(ids))
	}
	if !ids[12345] || !ids[67890] {
		t.Errorf("expected IDs 12345 and 67890 to be ignored, got %v", ids)
	}
}

func TestLoadIgnoredIDsEmptyList(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "ignored_activities.yml")
	if err := os.WriteFile(path, []byte("ignored: []\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	ids, err := LoadIgnoredIDs(path)
	if err != nil {
		t.Fatalf("LoadIgnoredIDs: %v", err)
	}
	if len(ids) != 0 {
		t.Errorf("expected empty set, got %v", ids)
	}
}

func TestLoadIgnoredIDsMissingFile(t *testing.T) {
	ids, err := LoadIgnoredIDs(filepath.Join(t.TempDir(), "does-not-exist.yml"))
	if err != nil {
		t.Fatalf("missing file must not be an error, got: %v", err)
	}
	if len(ids) != 0 {
		t.Errorf("expected empty set for missing file, got %v", ids)
	}
}

func TestLoadIgnoredIDsMalformedYAML(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "ignored_activities.yml")
	if err := os.WriteFile(path, []byte("ignored: {not: [valid"), 0o644); err != nil {
		t.Fatal(err)
	}

	if _, err := LoadIgnoredIDs(path); err == nil {
		t.Error("expected an error for malformed YAML")
	}
}
