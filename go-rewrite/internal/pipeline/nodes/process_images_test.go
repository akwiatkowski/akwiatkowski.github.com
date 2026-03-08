package nodes

import (
	"image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"
	"testing"
	"time"

	"odkrywajac/internal/model"
	"odkrywajac/internal/pipeline"
)

// createTestJPEG writes a small solid-color JPEG to path.
func createTestJPEG(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	img := image.NewRGBA(image.Rect(0, 0, 100, 80))
	for y := range 80 {
		for x := range 100 {
			img.Set(x, y, color.RGBA{R: 200, G: 100, B: 50, A: 255})
		}
	}
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := jpeg.Encode(f, img, &jpeg.Options{Quality: 80}); err != nil {
		t.Fatal(err)
	}
}

func TestProcessImages(t *testing.T) {
	tmp := t.TempDir()
	date := time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC)
	post := &model.Post{
		Slug: "test-post",
		Date: date,
	}

	// Create source image dir: env/dev/data/images/2021/2021-07-18-test-post/
	srcDir := filepath.Join(tmp, "env", "dev", "data", "images", "2021", "2021-07-18-test-post")
	createTestJPEG(t, filepath.Join(srcDir, "photo1.jpg"))

	ctx := &pipeline.Context{
		Env:      "dev",
		Target:   "go",
		BasePath: tmp,
		Workers:  2,
		Verbose:  false,
	}

	node := NewProcessImagesNode([]*model.Post{post})
	if err := node.Run(ctx); err != nil {
		t.Fatalf("Run() error: %v", err)
	}

	outDir := filepath.Join(tmp, "env", "dev", "public", "go")

	// Verify raw image copied
	rawPath := filepath.Join(outDir, "images", "2021", "2021-07-18-test-post", "photo1.jpg")
	if _, err := os.Stat(rawPath); err != nil {
		t.Errorf("raw image not copied: %s", rawPath)
	}

	// Verify 8 processed files (4 sizes × 2 formats)
	procDir := filepath.Join(outDir, "images", "processed", "2021", "07")
	sizes := []string{"article", "card", "grid", "thumbnail"}
	formats := []string{"jpg", "avif"}

	for _, sz := range sizes {
		for _, fmt := range formats {
			name := "2021-07-18-test-post_photo1_" + sz + "." + fmt
			path := filepath.Join(procDir, name)
			info, err := os.Stat(path)
			if err != nil {
				t.Errorf("missing processed image: %s", name)
				continue
			}
			if info.Size() == 0 {
				t.Errorf("empty processed image: %s", name)
			}
		}
	}

	// Get result stats
	res, ok := ctx.Result("process_images")
	if !ok {
		t.Fatal("no process_images result stored")
	}
	result := res.(ProcessImagesResult)
	if result.RawCopied != 1 {
		t.Errorf("RawCopied = %d, want 1", result.RawCopied)
	}
	if result.Processed != 8 {
		t.Errorf("Processed = %d, want 8", result.Processed)
	}
}

func TestProcessImagesCaching(t *testing.T) {
	tmp := t.TempDir()
	date := time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC)
	post := &model.Post{
		Slug: "cache-test",
		Date: date,
	}

	srcDir := filepath.Join(tmp, "env", "dev", "data", "images", "2021", "2021-07-18-cache-test")
	createTestJPEG(t, filepath.Join(srcDir, "photo1.jpg"))

	ctx := &pipeline.Context{
		Env:      "dev",
		Target:   "go",
		BasePath: tmp,
		Workers:  1,
	}

	node := NewProcessImagesNode([]*model.Post{post})

	// First run — should process everything
	if err := node.Run(ctx); err != nil {
		t.Fatalf("first Run() error: %v", err)
	}
	r1, _ := ctx.Result("process_images")
	first := r1.(ProcessImagesResult)
	if first.Processed != 8 {
		t.Errorf("first run: Processed = %d, want 8", first.Processed)
	}

	// Second run — everything should be skipped
	if err := node.Run(ctx); err != nil {
		t.Fatalf("second Run() error: %v", err)
	}
	r2, _ := ctx.Result("process_images")
	second := r2.(ProcessImagesResult)
	if second.Processed != 0 {
		t.Errorf("second run: Processed = %d, want 0 (all cached)", second.Processed)
	}
	if second.ProcessSkipped != 8 {
		t.Errorf("second run: ProcessSkipped = %d, want 8", second.ProcessSkipped)
	}
	if second.RawSkipped != 1 {
		t.Errorf("second run: RawSkipped = %d, want 1", second.RawSkipped)
	}
}

func TestProcessImagesNoSourceDir(t *testing.T) {
	tmp := t.TempDir()
	date := time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC)
	post := &model.Post{
		Slug: "no-images",
		Date: date,
	}

	ctx := &pipeline.Context{
		Env:      "dev",
		Target:   "go",
		BasePath: tmp,
		Workers:  1,
	}

	node := NewProcessImagesNode([]*model.Post{post})
	if err := node.Run(ctx); err != nil {
		t.Fatalf("Run() error: %v", err)
	}

	r, _ := ctx.Result("process_images")
	result := r.(ProcessImagesResult)
	if result.RawCopied != 0 || result.Processed != 0 {
		t.Errorf("expected zero work for missing source dir, got copied=%d processed=%d",
			result.RawCopied, result.Processed)
	}
}
