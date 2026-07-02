// Package nodes provides pipeline node implementations.
package nodes

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"odkrywajac/internal/pipeline"
)

// CopyAssetsNode copies static assets from data/assets/ to the output directory.
// It skips files where size and mtime already match, preserving destination mtimes
// for unchanged files (important for ?v= cache param stability).
type CopyAssetsNode struct{}

func NewCopyAssetsNode() *CopyAssetsNode { return &CopyAssetsNode{} }

func (n *CopyAssetsNode) Name() string   { return "copy_assets" }
func (n *CopyAssetsNode) Deps() []string { return nil }

func (n *CopyAssetsNode) IsStale(ctx *pipeline.Context) (bool, error) {
	return true, nil // always run; skip logic is per-file inside Run
}

// CopyAssetsResult holds stats from a copy_assets run.
type CopyAssetsResult struct {
	Copied  int
	Skipped int
}

func (n *CopyAssetsNode) Run(ctx *pipeline.Context) error {
	dstDir := ctx.OutputDir()

	// Copy assets from the single shared source (data/assets/). The former
	// data/assets overlay was merged into data/assets — one source now.
	copied, skipped, err := copyAssetsDir(ctx.AssetsDir(), dstDir)
	if err != nil {
		return fmt.Errorf("copy assets: %w", err)
	}

	if ctx.Verbose {
		fmt.Printf("  Assets: %d copied, %d skipped\n", copied, skipped)
	}

	ctx.StoreResult("copy_assets", CopyAssetsResult{Copied: copied, Skipped: skipped})
	return nil
}

// copyAssetsDir walks srcDir and copies files to dstDir, skipping unchanged files.
// Returns (copied, skipped, error).
func copyAssetsDir(srcDir, dstDir string) (int, int, error) {
	var copied, skipped int

	err := filepath.Walk(srcDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}

		rel, err := filepath.Rel(srcDir, path)
		if err != nil {
			return err
		}
		dst := filepath.Join(dstDir, rel)

		// Skip if destination has same size and mtime
		if dstInfo, err := os.Stat(dst); err == nil {
			if dstInfo.Size() == info.Size() && !dstInfo.ModTime().Before(info.ModTime()) {
				skipped++
				return nil
			}
		}

		// Copy the file
		if err := copyFile(path, dst, info); err != nil {
			return fmt.Errorf("copy %s: %w", rel, err)
		}
		copied++
		return nil
	})

	return copied, skipped, err
}

// copyFile copies src to dst, creating parent directories as needed.
// It preserves the source file's modification time.
func copyFile(src, dst string, srcInfo os.FileInfo) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}

	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	if _, err := io.Copy(out, in); err != nil {
		return err
	}

	// Preserve mtime so ?v= stays stable across builds
	return os.Chtimes(dst, srcInfo.ModTime(), srcInfo.ModTime())
}

// VersionForFile returns the mtime of a file as a unix timestamp string,
// suitable for use as a cache-busting query parameter.
// Returns "" if the file doesn't exist.
func VersionForFile(path string) string {
	info, err := os.Stat(path)
	if err != nil {
		return ""
	}
	return fmt.Sprintf("%d", info.ModTime().Unix())
}

// StripLeadingSlash removes a leading "/" from a URL path to make it
// relative for filesystem lookups.
func StripLeadingSlash(urlPath string) string {
	return strings.TrimPrefix(urlPath, "/")
}
