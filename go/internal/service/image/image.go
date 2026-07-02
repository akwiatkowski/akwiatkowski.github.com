// Package image resizes source photos into the site's JPEG+AVIF variants.
// It is the image-processing service (mirrors Crystal's ImageResizer); the
// pipeline's process_images node handles discovery/orchestration and calls
// ProcessImage per source file.
package image

import (
	"fmt"
	"image"
	"image/jpeg"
	"os"
	"path/filepath"
	"strings"

	"github.com/disintegration/imaging"
	"github.com/gen2brain/avif"

	"odkrywajac/internal/model"
)

// Size defines a resize target: dimensions and per-format quality.
type Size struct {
	Name        string
	Width       int
	Height      int
	JPEGQuality int
	AVIFQuality int
}

// Sizes are the variants generated for every source photo. Order is not
// significant. Kept in sync with the URL helpers that reference these names.
var Sizes = []Size{
	{"article", 1000, 800, 85, 53},
	{"card", 700, 525, 82, 53},
	{"grid", 560, 420, 80, 53},
	{"thumbnail", 150, 112, 72, 53},
}

// ProcessImage resizes one source image to all Sizes × 2 formats (JPEG+AVIF),
// writing to <outputDir>/images/processed/<year>/<month>/. Outputs already
// newer than the source are skipped. Returns (processed, skipped, errors).
func ProcessImage(srcPath string, post *model.Post, filename, outputDir string) (int, int, int) {
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
	for _, sz := range Sizes {
		for _, format := range []string{"jpg", "avif"} {
			outName := fmt.Sprintf("%s_%s_%s.%s", post.Slug, nameWithoutExt, sz.Name, format)
			outPath := filepath.Join(procDir, outName)
			if !outputFresh(outPath, srcInfo) {
				allFresh = false
				break
			}
		}
		if !allFresh {
			break
		}
	}
	if allFresh {
		return 0, len(Sizes) * 2, 0
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
	for _, sz := range Sizes {
		resized := imaging.Fill(srcImg, sz.Width, sz.Height, imaging.Center, imaging.Lanczos)

		// JPEG
		jpegName := fmt.Sprintf("%s_%s_%s.jpg", post.Slug, nameWithoutExt, sz.Name)
		jpegPath := filepath.Join(procDir, jpegName)
		if outputFresh(jpegPath, srcInfo) {
			skipped++
		} else if err := saveJPEG(resized, jpegPath, sz.JPEGQuality); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: JPEG encode %s: %v\n", jpegPath, err)
		} else {
			processed++
		}

		// AVIF
		avifName := fmt.Sprintf("%s_%s_%s.avif", post.Slug, nameWithoutExt, sz.Name)
		avifPath := filepath.Join(procDir, avifName)
		if outputFresh(avifPath, srcInfo) {
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

// outputFresh returns true if dst exists and is at least as new as srcInfo.
func outputFresh(dst string, srcInfo os.FileInfo) bool {
	dstInfo, err := os.Stat(dst)
	if err != nil {
		return false
	}
	return dstInfo.Size() > 0 && !dstInfo.ModTime().Before(srcInfo.ModTime())
}
