package pipeline

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestMaxMtime(t *testing.T) {
	dir := t.TempDir()

	f1 := filepath.Join(dir, "a.txt")
	os.WriteFile(f1, []byte("a"), 0644)
	time.Sleep(10 * time.Millisecond)

	f2 := filepath.Join(dir, "b.txt")
	os.WriteFile(f2, []byte("b"), 0644)

	max, err := MaxMtime(f1, f2)
	if err != nil {
		t.Fatal(err)
	}

	info2, _ := os.Stat(f2)
	if !max.Equal(info2.ModTime()) {
		t.Errorf("expected max to be b.txt mtime")
	}
}

func TestMaxMtimeSkipsNonExistent(t *testing.T) {
	dir := t.TempDir()
	f1 := filepath.Join(dir, "a.txt")
	os.WriteFile(f1, []byte("a"), 0644)

	max, err := MaxMtime(f1, filepath.Join(dir, "nonexistent.txt"))
	if err != nil {
		t.Fatal(err)
	}

	info, _ := os.Stat(f1)
	if !max.Equal(info.ModTime()) {
		t.Errorf("expected max to be a.txt mtime")
	}
}

func TestMaxMtimeAllNonExistent(t *testing.T) {
	max, err := MaxMtime("/nonexistent/a", "/nonexistent/b")
	if err != nil {
		t.Fatal(err)
	}
	if !max.IsZero() {
		t.Errorf("expected zero time, got %v", max)
	}
}

func TestFileNewerThan(t *testing.T) {
	dir := t.TempDir()

	target := filepath.Join(dir, "target.txt")
	os.WriteFile(target, []byte("t"), 0644)
	time.Sleep(10 * time.Millisecond)

	source := filepath.Join(dir, "source.txt")
	os.WriteFile(source, []byte("s"), 0644)

	newer, err := FileNewerThan(source, target)
	if err != nil {
		t.Fatal(err)
	}
	if !newer {
		t.Error("source should be newer than target")
	}

	// Reverse
	newer, err = FileNewerThan(target, source)
	if err != nil {
		t.Fatal(err)
	}
	if newer {
		t.Error("target should not be newer than source")
	}
}

func TestFileNewerThanMissingTarget(t *testing.T) {
	dir := t.TempDir()
	source := filepath.Join(dir, "source.txt")
	os.WriteFile(source, []byte("s"), 0644)

	newer, err := FileNewerThan(source, filepath.Join(dir, "missing.txt"))
	if err != nil {
		t.Fatal(err)
	}
	if !newer {
		t.Error("should be 'newer' when target is missing")
	}
}

func TestFileNewerThanMissingSource(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "target.txt")
	os.WriteFile(target, []byte("t"), 0644)

	newer, err := FileNewerThan(filepath.Join(dir, "missing.txt"), target)
	if err != nil {
		t.Fatal(err)
	}
	if newer {
		t.Error("should not be 'newer' when source is missing")
	}
}

func TestAnyNewerThan(t *testing.T) {
	dir := t.TempDir()

	target := filepath.Join(dir, "target.txt")
	os.WriteFile(target, []byte("t"), 0644)
	time.Sleep(10 * time.Millisecond)

	old := filepath.Join(dir, "old.txt")
	os.WriteFile(old, []byte("o"), 0644)
	// Touch old to be older than target
	past := time.Now().Add(-1 * time.Hour)
	os.Chtimes(old, past, past)

	fresh := filepath.Join(dir, "fresh.txt")
	os.WriteFile(fresh, []byte("f"), 0644)

	newer, err := AnyNewerThan([]string{old, fresh}, target)
	if err != nil {
		t.Fatal(err)
	}
	if !newer {
		t.Error("fresh.txt should be newer than target")
	}
}

func TestAnyNewerThanMissingTarget(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "src.txt")
	os.WriteFile(src, []byte("s"), 0644)

	newer, err := AnyNewerThan([]string{src}, filepath.Join(dir, "missing.txt"))
	if err != nil {
		t.Fatal(err)
	}
	if !newer {
		t.Error("should be newer when target is missing")
	}
}

func TestGlobNewerThan(t *testing.T) {
	dir := t.TempDir()

	target := filepath.Join(dir, "target.out")
	os.WriteFile(target, []byte("t"), 0644)
	time.Sleep(10 * time.Millisecond)

	src := filepath.Join(dir, "a.txt")
	os.WriteFile(src, []byte("a"), 0644)

	newer, err := GlobNewerThan(filepath.Join(dir, "*.txt"), target)
	if err != nil {
		t.Fatal(err)
	}
	if !newer {
		t.Error("glob match should be newer than target")
	}
}

func TestGlobNewerThanNoMatches(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "target.out")
	os.WriteFile(target, []byte("t"), 0644)

	newer, err := GlobNewerThan(filepath.Join(dir, "*.xyz"), target)
	if err != nil {
		t.Fatal(err)
	}
	if newer {
		t.Error("no matches should not be newer")
	}
}
