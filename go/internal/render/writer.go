package render

import (
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"sync/atomic"
	"time"
)

// OutputFile holds a rendered page ready to be written to disk.
type OutputFile struct {
	URL       string
	Content   []byte
	InputHash string // optional: set by InputHasher views for cache tracking
}

// WriteStats tracks write operation counts.
type WriteStats struct {
	Written atomic.Int64
	Skipped atomic.Int64
}

// Writer handles writing output files to disk with change detection.
type Writer struct {
	outputDir string
	manifest  *Manifest
	stats     WriteStats
}

// NewWriter creates a new Writer.
func NewWriter(outputDir string, manifest *Manifest) *Writer {
	return &Writer{
		outputDir: outputDir,
		manifest:  manifest,
	}
}

// Write writes an output file to disk if its content has changed.
func (w *Writer) Write(file OutputFile) error {
	hash := sha256Hash(file.Content)

	// Check manifest for unchanged content
	if existing, ok := w.manifest.Get(file.URL); ok {
		if existing.SHA256 == hash {
			w.stats.Skipped.Add(1)
			return nil
		}
	}

	// Build file path
	path := w.urlToPath(file.URL)

	// Ensure directory exists (MkdirAll is idempotent, fast when dir exists)
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("mkdir %s: %w", dir, err)
	}

	// Atomic write: write to .tmp, then rename
	tmpPath := path + ".tmp"
	if err := os.WriteFile(tmpPath, file.Content, 0o644); err != nil {
		return fmt.Errorf("write %s: %w", tmpPath, err)
	}
	if err := os.Rename(tmpPath, path); err != nil {
		os.Remove(tmpPath) // clean up on failure
		return fmt.Errorf("rename %s: %w", path, err)
	}

	// Update manifest
	w.manifest.Set(file.URL, ManifestEntry{
		SHA256:    hash,
		Size:      len(file.Content),
		BuiltAt:   time.Now().UTC().Format(time.RFC3339),
		InputHash: file.InputHash,
	})

	w.stats.Written.Add(1)
	return nil
}

// Stats returns write statistics.
func (w *Writer) Stats() (written, skipped int64) {
	return w.stats.Written.Load(), w.stats.Skipped.Load()
}

func (w *Writer) urlToPath(url string) string {
	// URL "/" maps to "index.html"
	if url == "/" {
		url = "/index.html"
	}
	return filepath.Join(w.outputDir, filepath.FromSlash(url))
}

func sha256Hash(data []byte) string {
	h := sha256.Sum256(data)
	return fmt.Sprintf("%x", h)
}
