package nodes

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"odkrywajac/internal/pipeline"
)

func TestCopyAssetsNode_CopiesFiles(t *testing.T) {
	baseDir := t.TempDir()

	// Create source asset files directly in data/assets/
	assetsDir := filepath.Join(baseDir, "data", "assets")
	cssDir := filepath.Join(assetsDir, "css")
	os.MkdirAll(cssDir, 0o755)
	os.WriteFile(filepath.Join(cssDir, "style.css"), []byte("body { color: red }"), 0o644)

	jsDir := filepath.Join(assetsDir, "js")
	os.MkdirAll(jsDir, 0o755)
	os.WriteFile(filepath.Join(jsDir, "app.js"), []byte("console.log('hi')"), 0o644)

	outputDir := filepath.Join(baseDir, "env", "dev", "public", "go")
	os.MkdirAll(outputDir, 0o755)

	ctx := &pipeline.Context{
		Env:      "dev",
		Target:   "go",
		BasePath: baseDir,
		Workers:  1,
	}

	node := NewCopyAssetsNode()

	if node.Name() != "copy_assets" {
		t.Errorf("expected name 'copy_assets', got %q", node.Name())
	}
	if node.Deps() != nil {
		t.Errorf("expected nil deps, got %v", node.Deps())
	}

	// Run the copy
	if err := node.Run(ctx); err != nil {
		t.Fatalf("Run failed: %v", err)
	}

	// Verify files were copied
	copiedCSS := filepath.Join(outputDir, "css", "style.css")
	data, err := os.ReadFile(copiedCSS)
	if err != nil {
		t.Fatalf("CSS not copied: %v", err)
	}
	if string(data) != "body { color: red }" {
		t.Errorf("CSS content mismatch: %q", data)
	}

	copiedJS := filepath.Join(outputDir, "js", "app.js")
	data, err = os.ReadFile(copiedJS)
	if err != nil {
		t.Fatalf("JS not copied: %v", err)
	}
	if string(data) != "console.log('hi')" {
		t.Errorf("JS content mismatch: %q", data)
	}

	// Check result was stored
	result, ok := ctx.Result("copy_assets")
	if !ok {
		t.Fatal("result not stored")
	}
	r := result.(CopyAssetsResult)
	if r.Copied != 2 {
		t.Errorf("expected 2 copied, got %d", r.Copied)
	}
	if r.Skipped != 0 {
		t.Errorf("expected 0 skipped, got %d", r.Skipped)
	}
}

func TestCopyAssetsNode_SkipsIdenticalFiles(t *testing.T) {
	baseDir := t.TempDir()
	assetsDir := filepath.Join(baseDir, "data", "assets")
	os.MkdirAll(assetsDir, 0o755)

	content := []byte("unchanged content")
	srcFile := filepath.Join(assetsDir, "test.css")
	os.WriteFile(srcFile, content, 0o644)

	// Set a known mtime on source
	mtime := time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)
	os.Chtimes(srcFile, mtime, mtime)

	outputDir := filepath.Join(baseDir, "env", "dev", "public", "go")
	os.MkdirAll(outputDir, 0o755)

	ctx := &pipeline.Context{
		Env:      "dev",
		Target:   "go",
		BasePath: baseDir,
		Workers:  1,
	}

	node := NewCopyAssetsNode()

	// First run: should copy
	if err := node.Run(ctx); err != nil {
		t.Fatalf("first run failed: %v", err)
	}
	r1 := mustResult(t, ctx)
	if r1.Copied != 1 {
		t.Errorf("first run: expected 1 copied, got %d", r1.Copied)
	}

	// Second run: should skip (same size + mtime)
	if err := node.Run(ctx); err != nil {
		t.Fatalf("second run failed: %v", err)
	}
	r2 := mustResult(t, ctx)
	if r2.Skipped != 1 {
		t.Errorf("second run: expected 1 skipped, got %d", r2.Skipped)
	}
	if r2.Copied != 0 {
		t.Errorf("second run: expected 0 copied, got %d", r2.Copied)
	}
}

func TestCopyAssetsNode_CopiesWhenContentChanges(t *testing.T) {
	baseDir := t.TempDir()
	assetsDir := filepath.Join(baseDir, "data", "assets")
	os.MkdirAll(assetsDir, 0o755)

	srcFile := filepath.Join(assetsDir, "test.css")
	os.WriteFile(srcFile, []byte("v1"), 0o644)

	outputDir := filepath.Join(baseDir, "env", "dev", "public", "go")
	os.MkdirAll(outputDir, 0o755)

	ctx := &pipeline.Context{
		Env:      "dev",
		Target:   "go",
		BasePath: baseDir,
		Workers:  1,
	}

	node := NewCopyAssetsNode()

	// First copy
	node.Run(ctx)

	// Change source file (different size triggers re-copy)
	os.WriteFile(srcFile, []byte("v2 with more content"), 0o644)

	if err := node.Run(ctx); err != nil {
		t.Fatalf("Run failed: %v", err)
	}
	r := mustResult(t, ctx)
	if r.Copied != 1 {
		t.Errorf("expected 1 copied after change, got %d", r.Copied)
	}

	// Verify new content
	data, _ := os.ReadFile(filepath.Join(outputDir, "test.css"))
	if string(data) != "v2 with more content" {
		t.Errorf("content not updated: %q", data)
	}
}

func TestCopyAssetsNode_IsAlwaysStale(t *testing.T) {
	node := NewCopyAssetsNode()
	stale, err := node.IsStale(nil)
	if err != nil {
		t.Fatal(err)
	}
	if !stale {
		t.Error("expected always stale")
	}
}

func TestCopyAssetsNode_PreservesMtime(t *testing.T) {
	baseDir := t.TempDir()
	assetsDir := filepath.Join(baseDir, "data", "assets")
	os.MkdirAll(assetsDir, 0o755)

	srcFile := filepath.Join(assetsDir, "test.js")
	os.WriteFile(srcFile, []byte("var x = 1"), 0o644)

	mtime := time.Date(2024, 6, 15, 12, 0, 0, 0, time.UTC)
	os.Chtimes(srcFile, mtime, mtime)

	outputDir := filepath.Join(baseDir, "env", "dev", "public", "go")
	os.MkdirAll(outputDir, 0o755)

	ctx := &pipeline.Context{
		Env:      "dev",
		Target:   "go",
		BasePath: baseDir,
		Workers:  1,
	}

	node := NewCopyAssetsNode()
	node.Run(ctx)

	dstInfo, err := os.Stat(filepath.Join(outputDir, "test.js"))
	if err != nil {
		t.Fatal(err)
	}
	if !dstInfo.ModTime().Equal(mtime) {
		t.Errorf("mtime not preserved: got %v, want %v", dstInfo.ModTime(), mtime)
	}
}

func TestSymlinkImages_NoopWhenMissing(t *testing.T) {
	baseDir := t.TempDir()
	outputDir := filepath.Join(baseDir, "env", "dev", "public", "go")
	os.MkdirAll(outputDir, 0o755)

	ctx := &pipeline.Context{
		Env:      "dev",
		Target:   "go",
		BasePath: baseDir,
		Workers:  1,
	}

	node := NewCopyAssetsNode()
	node.symlinkImages(ctx) // should not panic or error

	// Symlink should not exist
	_, err := os.Lstat(filepath.Join(outputDir, "images"))
	if !os.IsNotExist(err) {
		t.Error("expected no symlink when Crystal images don't exist")
	}
}

func TestSymlinkImages_CreatesSymlink(t *testing.T) {
	baseDir := t.TempDir()

	// Create fake Crystal images dir
	crystalImages := filepath.Join(baseDir, "env", "dev", "public", "local", "images")
	os.MkdirAll(crystalImages, 0o755)

	outputDir := filepath.Join(baseDir, "env", "dev", "public", "go")
	os.MkdirAll(outputDir, 0o755)

	ctx := &pipeline.Context{
		Env:      "dev",
		Target:   "go",
		BasePath: baseDir,
		Workers:  1,
	}

	node := NewCopyAssetsNode()
	node.symlinkImages(ctx)

	link := filepath.Join(outputDir, "images")
	target, err := os.Readlink(link)
	if err != nil {
		t.Fatalf("symlink not created: %v", err)
	}
	if target != crystalImages {
		t.Errorf("symlink target = %q, want %q", target, crystalImages)
	}
}

func mustResult(t *testing.T, ctx *pipeline.Context) CopyAssetsResult {
	t.Helper()
	result, ok := ctx.Result("copy_assets")
	if !ok {
		t.Fatal("result not stored")
	}
	return result.(CopyAssetsResult)
}
