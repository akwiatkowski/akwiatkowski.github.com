package nodes

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"odkrywajac/internal/model"
	"odkrywajac/internal/pipeline"
	"odkrywajac/internal/service/image"
)

// ProcessImagesNode copies raw images and generates resized JPEG+AVIF variants.
type ProcessImagesNode struct {
	posts []*model.Post
}

func NewProcessImagesNode(posts []*model.Post) *ProcessImagesNode {
	return &ProcessImagesNode{posts: posts}
}

func (n *ProcessImagesNode) Name() string   { return "process_images" }
func (n *ProcessImagesNode) Deps() []string { return nil }

func (n *ProcessImagesNode) IsStale(_ *pipeline.Context) (bool, error) {
	return true, nil // skip logic is per-file inside Run
}

// ProcessImagesResult holds stats from image processing.
type ProcessImagesResult struct {
	RawCopied      int
	RawSkipped     int
	Processed      int
	ProcessSkipped int
	Errors         int
}

func (n *ProcessImagesNode) Run(ctx *pipeline.Context) error {
	imagesDir := ctx.ImagesDir()
	outputDir := ctx.OutputDir()

	// Step A: copy raw images
	var rawCopied, rawSkipped int
	for _, post := range n.posts {
		srcDir := filepath.Join(imagesDir, fmt.Sprintf("%d", post.Date.Year()), post.Slug)
		dstDir := filepath.Join(outputDir, "images", fmt.Sprintf("%d", post.Date.Year()), post.Slug)

		entries, err := os.ReadDir(srcDir)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return fmt.Errorf("read image dir %s: %w", srcDir, err)
		}

		for _, entry := range entries {
			if entry.IsDir() || !isImageFile(entry.Name()) {
				continue
			}
			src := filepath.Join(srcDir, entry.Name())
			dst := filepath.Join(dstDir, entry.Name())

			srcInfo, err := entry.Info()
			if err != nil {
				return err
			}

			if skipCopy(dst, srcInfo) {
				rawSkipped++
				continue
			}

			if err := copyFile(src, dst, srcInfo); err != nil {
				return fmt.Errorf("copy raw image %s: %w", src, err)
			}
			rawCopied++
		}
	}

	// Step B: resize & encode in parallel
	type job struct {
		srcPath  string
		post     *model.Post
		filename string
	}

	var jobs []job
	for _, post := range n.posts {
		srcDir := filepath.Join(imagesDir, fmt.Sprintf("%d", post.Date.Year()), post.Slug)
		entries, err := os.ReadDir(srcDir)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return fmt.Errorf("read image dir %s: %w", srcDir, err)
		}
		for _, entry := range entries {
			if entry.IsDir() || !isImageFile(entry.Name()) {
				continue
			}
			jobs = append(jobs, job{
				srcPath:  filepath.Join(srcDir, entry.Name()),
				post:     post,
				filename: entry.Name(),
			})
		}
	}

	workers := ctx.Workers
	if workers < 1 {
		workers = 1
	}

	var processed, procSkipped, errCount atomic.Int64
	var done atomic.Int64
	var wg sync.WaitGroup
	ch := make(chan job, len(jobs))

	for _, j := range jobs {
		ch <- j
	}
	close(ch)

	// Progress bar for large batches (>10 images)
	total := len(jobs)
	var stopProgress chan struct{}
	if total > 10 {
		stopProgress = make(chan struct{})
		go func() {
			ticker := time.NewTicker(200 * time.Millisecond)
			defer ticker.Stop()
			for {
				select {
				case <-ticker.C:
					d := int(done.Load())
					pct := d * 100 / total
					barLen := 30
					filled := pct * barLen / 100
					bar := strings.Repeat("█", filled) + strings.Repeat("░", barLen-filled)
					fmt.Fprintf(os.Stderr, "\r\033[2K  Images [%s] %d/%d (%d%%)", bar, d, total, pct)
				case <-stopProgress:
					fmt.Fprintf(os.Stderr, "\r\033[2K")
					return
				}
			}
		}()
	}

	for range workers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := range ch {
				p, s, e := image.ProcessImage(j.srcPath, j.post, j.filename, outputDir)
				processed.Add(int64(p))
				procSkipped.Add(int64(s))
				errCount.Add(int64(e))
				done.Add(1)
			}
		}()
	}
	wg.Wait()

	if stopProgress != nil {
		close(stopProgress)
	}

	result := ProcessImagesResult{
		RawCopied:      rawCopied,
		RawSkipped:     rawSkipped,
		Processed:      int(processed.Load()),
		ProcessSkipped: int(procSkipped.Load()),
		Errors:         int(errCount.Load()),
	}

	if ctx.Verbose {
		fmt.Printf("  Images: %d raw copied (%d skipped), %d processed (%d skipped, %d errors)\n",
			result.RawCopied, result.RawSkipped, result.Processed, result.ProcessSkipped, result.Errors)
	}

	ctx.StoreResult("process_images", result)
	return nil
}

// skipCopy returns true if dst exists and is at least as new as srcInfo.
func skipCopy(dst string, srcInfo os.FileInfo) bool {
	dstInfo, err := os.Stat(dst)
	if err != nil {
		return false
	}
	return dstInfo.Size() > 0 && !dstInfo.ModTime().Before(srcInfo.ModTime())
}

// isImageFile returns true for common image extensions.
func isImageFile(name string) bool {
	lower := strings.ToLower(name)
	return strings.HasSuffix(lower, ".jpg") ||
		strings.HasSuffix(lower, ".jpeg") ||
		strings.HasSuffix(lower, ".png")
}
