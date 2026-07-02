package exif

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

// crystalEntry mirrors the Crystal EXIF cache YAML format.
type crystalEntry struct {
	ImageFilename string   `yaml:"image_filename"`
	PostSlug      string   `yaml:"post_slug"`
	Lat           *float64 `yaml:"lat"`
	Lon           *float64 `yaml:"lon"`
	Altitude      *float64 `yaml:"altitude"`
	FocalLength   *float64 `yaml:"focal_length"`
	FocalLength35 *float64 `yaml:"focal_length_35"`
	Crop          *float64 `yaml:"crop"`
	Aperture      *float64 `yaml:"aperture"`
	Exposure      *float64 `yaml:"exposure"`
	ExposureStr   string   `yaml:"exposure_string"`
	FocusDistance *float64 `yaml:"focus_distance"`
	ISO           *int     `yaml:"iso"`
	Width         *int     `yaml:"width"`
	Height        *int     `yaml:"height"`
	Lens          string   `yaml:"lens"`
	Camera        string   `yaml:"camera"`
	Time          string   `yaml:"time"`
}

// TestCompareWithCrystalCache reads Crystal's EXIF cache and compares with Go's EXIF
// reading for every photo. Run with -v to see details, or limit to dev with -run flag.
//
// Usage:
//
//	go test ./internal/exif/ -run TestCompareWithCrystalCache -v
//	EXIF_TEST_ENV=full go test ./internal/exif/ -run TestCompareWithCrystalCache -v -timeout 5m
func TestCompareWithCrystalCache(t *testing.T) {
	env := os.Getenv("EXIF_TEST_ENV")
	if env == "" {
		env = "dev"
	}

	projectRoot := findProjectRoot(t)
	cacheDir := filepath.Join(projectRoot, "env", env, "cache", "exifs")
	imagesDir := filepath.Join(projectRoot, "env", env, "data", "images")

	cacheFiles, err := filepath.Glob(filepath.Join(cacheDir, "*.yml"))
	if err != nil || len(cacheFiles) == 0 {
		t.Skipf("no Crystal cache files in %s", cacheDir)
	}

	var stats struct {
		totalImages   int
		withExif      int // Crystal cache has EXIF data for this image
		goReadOK      int // Go successfully read EXIF
		goReadFail    int // Go failed to read EXIF
		latMatch      int
		lonMatch      int
		cameraMatch   int
		lensMatch     int
		isoMatch      int
		widthMatch    int
		focalMatch    int
		apertureMatch int
		mismatches    int
	}

	for _, cacheFile := range cacheFiles {
		postSlug := strings.TrimSuffix(filepath.Base(cacheFile), ".yml")

		data, err := os.ReadFile(cacheFile)
		if err != nil {
			t.Errorf("read cache %s: %v", postSlug, err)
			continue
		}

		var crystalEntries []crystalEntry
		if err := yaml.Unmarshal(data, &crystalEntries); err != nil {
			t.Errorf("parse cache %s: %v", postSlug, err)
			continue
		}

		// Find images directory for this post
		postImagesDir := findPostImagesDir(imagesDir, postSlug)

		for _, ce := range crystalEntries {
			stats.totalImages++

			imgPath := filepath.Join(postImagesDir, ce.ImageFilename)
			if _, err := os.Stat(imgPath); err != nil {
				// Image file doesn't exist (may be in a different year subdir)
				continue
			}

			hasData := ce.Camera != "" || ce.Lat != nil || ce.Width != nil
			if hasData {
				stats.withExif++
			}

			goExif, err := ReadExif(imgPath)
			if err != nil {
				stats.goReadFail++
				if hasData {
					t.Logf("FAIL %s/%s: Go failed but Crystal has data: %v", postSlug, ce.ImageFilename, err)
				}
				continue
			}
			stats.goReadOK++

			// Compare fields
			if ce.Camera != "" {
				if goExif.Camera == ce.Camera {
					stats.cameraMatch++
				} else {
					logMismatch(t, postSlug, ce.ImageFilename, "camera", ce.Camera, goExif.Camera)
					stats.mismatches++
				}
			}

			if ce.Lens != "" {
				if goExif.Lens == ce.Lens {
					stats.lensMatch++
				} else {
					logMismatch(t, postSlug, ce.ImageFilename, "lens", ce.Lens, goExif.Lens)
					stats.mismatches++
				}
			}

			if ce.Lat != nil && goExif.Lat != nil {
				if nearEqual(*ce.Lat, *goExif.Lat, 0.0001) {
					stats.latMatch++
				} else {
					logMismatch(t, postSlug, ce.ImageFilename, "lat",
						fmt.Sprintf("%.6f", *ce.Lat), fmt.Sprintf("%.6f", *goExif.Lat))
					stats.mismatches++
				}
			}

			if ce.Lon != nil && goExif.Lon != nil {
				if nearEqual(*ce.Lon, *goExif.Lon, 0.0001) {
					stats.lonMatch++
				} else {
					logMismatch(t, postSlug, ce.ImageFilename, "lon",
						fmt.Sprintf("%.6f", *ce.Lon), fmt.Sprintf("%.6f", *goExif.Lon))
					stats.mismatches++
				}
			}

			if ce.ISO != nil && goExif.ISO != nil {
				if *ce.ISO == *goExif.ISO {
					stats.isoMatch++
				} else {
					logMismatch(t, postSlug, ce.ImageFilename, "iso",
						fmt.Sprintf("%d", *ce.ISO), fmt.Sprintf("%d", *goExif.ISO))
					stats.mismatches++
				}
			}

			if ce.Width != nil && goExif.Width != nil {
				if *ce.Width == *goExif.Width {
					stats.widthMatch++
				} else {
					logMismatch(t, postSlug, ce.ImageFilename, "width",
						fmt.Sprintf("%d", *ce.Width), fmt.Sprintf("%d", *goExif.Width))
					stats.mismatches++
				}
			}

			if ce.FocalLength != nil && goExif.FocalLength != nil {
				if nearEqual(*ce.FocalLength, *goExif.FocalLength, 0.1) {
					stats.focalMatch++
				} else {
					logMismatch(t, postSlug, ce.ImageFilename, "focal_length",
						fmt.Sprintf("%.1f", *ce.FocalLength), fmt.Sprintf("%.1f", *goExif.FocalLength))
					stats.mismatches++
				}
			}

			if ce.Aperture != nil && goExif.Aperture != nil {
				if nearEqual(*ce.Aperture, *goExif.Aperture, 0.1) {
					stats.apertureMatch++
				} else {
					logMismatch(t, postSlug, ce.ImageFilename, "aperture",
						fmt.Sprintf("%.1f", *ce.Aperture), fmt.Sprintf("%.1f", *goExif.Aperture))
					stats.mismatches++
				}
			}
		}
	}

	// Print summary
	t.Logf("\n=== EXIF Comparison Summary (%s env) ===", env)
	t.Logf("Total images in cache: %d", stats.totalImages)
	t.Logf("Images with Crystal EXIF data: %d", stats.withExif)
	t.Logf("Go read OK: %d, Go read fail: %d", stats.goReadOK, stats.goReadFail)
	t.Logf("Matches — camera:%d lens:%d lat:%d lon:%d iso:%d width:%d focal:%d aperture:%d",
		stats.cameraMatch, stats.lensMatch, stats.latMatch, stats.lonMatch,
		stats.isoMatch, stats.widthMatch, stats.focalMatch, stats.apertureMatch)
	t.Logf("Mismatches: %d", stats.mismatches)

	if stats.goReadOK == 0 {
		t.Error("Go could not read EXIF from any image")
	}
}

func logMismatch(t *testing.T, postSlug, filename, field, crystal, goVal string) {
	t.Helper()
	t.Logf("MISMATCH %s/%s %s: crystal=%q go=%q", postSlug, filename, field, crystal, goVal)
}

func nearEqual(a, b, epsilon float64) bool {
	return math.Abs(a-b) < epsilon
}

// findProjectRoot walks up from CWD to find the project root (contains data/config/).
func findProjectRoot(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "data", "config")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Skip("could not find project root")
		}
		dir = parent
	}
}

// findPostImagesDir locates the images directory for a post slug.
// Post images are stored in env/{env}/data/images/{year}/{slug}/.
func findPostImagesDir(imagesDir, postSlug string) string {
	// Extract year from slug (first 4 chars: "2021-07-18-..." → "2021")
	if len(postSlug) >= 4 {
		year := postSlug[:4]
		dir := filepath.Join(imagesDir, year, postSlug)
		if _, err := os.Stat(dir); err == nil {
			return dir
		}
	}
	// Fallback: search all year directories
	entries, _ := os.ReadDir(imagesDir)
	for _, e := range entries {
		if e.IsDir() {
			dir := filepath.Join(imagesDir, e.Name(), postSlug)
			if _, err := os.Stat(dir); err == nil {
				return dir
			}
		}
	}
	return filepath.Join(imagesDir, postSlug)
}
