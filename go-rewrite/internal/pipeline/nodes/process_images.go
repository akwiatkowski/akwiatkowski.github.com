package nodes

import (
	"fmt"
	"image"
	"image/jpeg"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/disintegration/imaging"
	"github.com/gen2brain/avif"

	"odkrywajac/internal/model"
	"odkrywajac/internal/pipeline"
)

// imageSize defines a resize target.
type imageSize struct {
	Name        string
	Width       int
	Height      int
	JPEGQuality int
	AVIFQuality int
}

var imageSizes = []imageSize{
	{"article", 1000, 800, 85, 53},
	{"card", 700, 525, 82, 53},
	{"grid", 560, 420, 80, 53},
	{"thumbnail", 150, 112, 72, 53},
}

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
	var wg sync.WaitGroup
	ch := make(chan job, len(jobs))

	for _, j := range jobs {
		ch <- j
	}
	close(ch)

	for range workers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := range ch {
				p, s, e := processImage(j.srcPath, j.post, j.filename, outputDir)
				processed.Add(int64(p))
				procSkipped.Add(int64(s))
				errCount.Add(int64(e))
			}
		}()
	}
	wg.Wait()

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

// processImage resizes one source image to all sizes × 2 formats.
// Returns (processed, skipped, errors).
func processImage(srcPath string, post *model.Post, filename, outputDir string) (int, int, int) {
	nameWithoutExt := filename
	if idx := strings.LastIndex(filename, "."); idx > 0 {
		nameWithoutExt = filename[:idx]
	}

	procDir := filepath.Join(outputDir, "images", "processed",
		fmt.Sprintf("%d", post.Date.Year()),
		fmt.Sprintf("%02d", post.Date.Month()))

	// Check if all outputs already exist and are newer than source
	srcInfo, err := os.Stat(srcPath)
	if err != nil {
		return 0, 0, 1
	}

	allFresh := true
	for _, sz := range imageSizes {
		for _, format := range []string{"jpg", "avif"} {
			outName := fmt.Sprintf("%s_%s_%s.%s", post.Slug, nameWithoutExt, sz.Name, format)
			outPath := filepath.Join(procDir, outName)
			if !skipCopy(outPath, srcInfo) {
				allFresh = false
				break
			}
		}
		if !allFresh {
			break
		}
	}
	if allFresh {
		return 0, len(imageSizes) * 2, 0
	}

	// Open source image once
	srcImg, err := imaging.Open(srcPath, imaging.AutoOrientation(true))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: could not open image %s: %v\n", srcPath, err)
		return 0, 0, 1
	}

	if err := os.MkdirAll(procDir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: could not create dir %s: %v\n", procDir, err)
		return 0, 0, 1
	}

	var processed, skipped int
	for _, sz := range imageSizes {
		resized := imaging.Fill(srcImg, sz.Width, sz.Height, imaging.Center, imaging.Lanczos)

		// JPEG
		jpegName := fmt.Sprintf("%s_%s_%s.jpg", post.Slug, nameWithoutExt, sz.Name)
		jpegPath := filepath.Join(procDir, jpegName)
		if skipCopy(jpegPath, srcInfo) {
			skipped++
		} else if err := saveJPEG(resized, jpegPath, sz.JPEGQuality); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: JPEG encode %s: %v\n", jpegPath, err)
		} else {
			processed++
		}

		// AVIF
		avifName := fmt.Sprintf("%s_%s_%s.avif", post.Slug, nameWithoutExt, sz.Name)
		avifPath := filepath.Join(procDir, avifName)
		if skipCopy(avifPath, srcInfo) {
			skipped++
		} else if err := saveAVIF(resized, avifPath, sz.AVIFQuality); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: AVIF encode %s: %v\n", avifPath, err)
		} else {
			processed++
		}
	}

	return processed, skipped, 0
}

// saveJPEG encodes an image as JPEG with the given quality.
func saveJPEG(img image.Image, path string, quality int) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return jpeg.Encode(f, img, &jpeg.Options{Quality: quality})
}

// saveAVIF encodes an image as AVIF with the given quality.
func saveAVIF(img image.Image, path string, quality int) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return avif.Encode(f, img, avif.Options{Quality: quality})
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
