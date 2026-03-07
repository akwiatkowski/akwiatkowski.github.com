package exif

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

// findTestImages walks up from the test directory to find JPEGs in the dev images.
func findTestImages(t *testing.T) []string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for {
		imagesDir := filepath.Join(dir, "env", "dev", "data", "images")
		if _, err := os.Stat(imagesDir); err == nil {
			var found []string
			filepath.WalkDir(imagesDir, func(path string, d os.DirEntry, err error) error {
				if err != nil || d.IsDir() {
					return nil
				}
				if ext := filepath.Ext(path); ext == ".jpg" || ext == ".JPG" || ext == ".jpeg" {
					found = append(found, path)
				}
				return nil
			})
			if len(found) > 0 {
				return found
			}
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Skip("could not find test JPEGs in dev images")
		}
		dir = parent
	}
}

func TestReadExif(t *testing.T) {
	images := findTestImages(t)

	// Try multiple images — some may have malformed EXIF
	var successCount int
	for _, imgPath := range images {
		data, err := ReadExif(imgPath)
		if err != nil {
			t.Logf("ReadExif(%s): %v (skipping)", filepath.Base(imgPath), err)
			continue
		}
		successCount++

		// Log what we found
		if data.Camera != "" {
			t.Logf("%s: camera=%s", filepath.Base(imgPath), data.Camera)
		}
		if data.Lat != nil {
			t.Logf("%s: GPS=%.4f,%.4f", filepath.Base(imgPath), *data.Lat, *data.Lon)
		}

		// At least one image should have a camera
		if data.Camera == "" && data.Lens == "" {
			t.Logf("%s: no camera or lens info", filepath.Base(imgPath))
		}

		// Only test a few images
		if successCount >= 3 {
			break
		}
	}

	if successCount == 0 {
		t.Error("could not read EXIF from any test image")
	}
}

func TestFormatExposure(t *testing.T) {
	tests := []struct {
		exp  float64
		want string
	}{
		{0.01, "1/100 s"},
		{0.001, "1/1000 s"},
		{1.0, "1.0 s"},
		{2.5, "2.5 s"},
		{0, ""},
	}
	for _, tt := range tests {
		got := formatExposure(tt.exp)
		if got != tt.want {
			t.Errorf("formatExposure(%v) = %q, want %q", tt.exp, got, tt.want)
		}
	}
}

func TestFormatLensSpec(t *testing.T) {
	tests := []struct {
		minFocal, maxFocal, minFStopWide, minFStopTele float64
		want                                           string
	}{
		{12, 100, 4.0, 4.0, "12-100mm f/4.0"},       // constant aperture zoom
		{28, 75, 2.8, 2.8, "28-75mm f/2.8"},          // constant aperture zoom
		{50, 50, 1.8, 1.8, "50mm f/1.8"},             // prime lens
		{18, 55, 3.5, 5.6, "18-55mm f/3.5-5.6"},      // variable aperture zoom
		{100, 400, 4.5, 6.3, "100-400mm f/4.5-6.3"},   // variable aperture tele
		{50, 0, 1.4, 0, "50mm f/1.4"},                 // prime, max focal = 0
		{0, 0, 0, 0, ""},                              // no data
	}
	for _, tt := range tests {
		got := formatLensSpec(tt.minFocal, tt.maxFocal, tt.minFStopWide, tt.minFStopTele)
		if got != tt.want {
			t.Errorf("formatLensSpec(%g, %g, %g, %g) = %q, want %q",
				tt.minFocal, tt.maxFocal, tt.minFStopWide, tt.minFStopTele, got, tt.want)
		}
	}
}

func TestReadExifNewFields(t *testing.T) {
	images := findTestImages(t)

	// Read first successful image and check new fields are populated
	for _, imgPath := range images {
		data, err := ReadExif(imgPath)
		if err != nil {
			continue
		}

		// Log all new fields
		biasStr := "<nil>"
		if data.ExposureBias != nil {
			biasStr = fmt.Sprintf("%.1f", *data.ExposureBias)
		}
		t.Logf("%s: exposure_program=%q exposure_bias=%s timezone=%q",
			filepath.Base(imgPath), data.ExposureProgram, biasStr, data.TimezoneOffset)
		minF, maxF, minFS, maxFS := "<nil>", "<nil>", "<nil>", "<nil>"
		if data.LensMinFocal != nil {
			minF = fmt.Sprintf("%.0f", *data.LensMinFocal)
		}
		if data.LensMaxFocal != nil {
			maxF = fmt.Sprintf("%.0f", *data.LensMaxFocal)
		}
		if data.LensMinFStop != nil {
			minFS = fmt.Sprintf("%.1f", *data.LensMinFStop)
		}
		if data.LensMaxFStop != nil {
			maxFS = fmt.Sprintf("%.1f", *data.LensMaxFStop)
		}
		t.Logf("%s: lens_spec=%q min_focal=%s max_focal=%s min_fstop=%s max_fstop=%s",
			filepath.Base(imgPath), data.LensSpecStr, minF, maxF, minFS, maxFS)
		t.Logf("%s: gps_map_datum=%q", filepath.Base(imgPath), data.GPSMapDatum)

		// ExposureProgram should be set for any real camera
		if data.ExposureProgram == "" {
			t.Logf("%s: no exposure program (unexpected for camera image)", filepath.Base(imgPath))
		}

		return // one image is enough
	}
	t.Skip("no images readable")
}

func TestCleanEquipmentName(t *testing.T) {
	tests := []struct {
		input, want string
	}{
		{"OLYMPUS M.12-100mm F4.0", "M.12-100mm F4.0"},
		{"Canon EF 50mm f/1.8", "EF 50mm f/1.8"},
		{"E-M1MarkII", "E-M1MarkII"},
	}
	for _, tt := range tests {
		got := cleanEquipmentName(tt.input)
		if got != tt.want {
			t.Errorf("cleanEquipmentName(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}
