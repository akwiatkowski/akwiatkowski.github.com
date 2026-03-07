package exif

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

// Cache manages per-post EXIF cache files at cacheDir/{post_slug}.yml.
type Cache struct {
	cacheDir string
}

// NewCache creates a new EXIF cache manager.
func NewCache(cacheDir string) *Cache {
	return &Cache{cacheDir: filepath.Join(cacheDir, "exif")}
}

// cachePath returns the path to the cache file for a post.
func (c *Cache) cachePath(postSlug string) string {
	return filepath.Join(c.cacheDir, postSlug+".yml")
}

// IsStale checks if the cache for a post needs regeneration.
// Returns true if cache doesn't exist or any source image is newer.
func (c *Cache) IsStale(postSlug string, imageFiles []string) bool {
	info, err := os.Stat(c.cachePath(postSlug))
	if err != nil {
		return true // doesn't exist
	}
	cacheMtime := info.ModTime()

	for _, img := range imageFiles {
		imgInfo, err := os.Stat(img)
		if err != nil {
			continue
		}
		if imgInfo.ModTime().After(cacheMtime) {
			return true
		}
	}
	return false
}

// Load reads cached EXIF data for a post.
func (c *Cache) Load(postSlug string) ([]*model.ExifData, error) {
	data, err := os.ReadFile(c.cachePath(postSlug))
	if err != nil {
		return nil, fmt.Errorf("read cache %s: %w", postSlug, err)
	}

	var entries []cacheEntry
	if err := yaml.Unmarshal(data, &entries); err != nil {
		return nil, fmt.Errorf("parse cache %s: %w", postSlug, err)
	}

	var results []*model.ExifData
	for _, e := range entries {
		results = append(results, e.toExifData())
	}
	return results, nil
}

// Generate reads EXIF from source images and writes the cache file.
func (c *Cache) Generate(postSlug string, imageFiles []string) error {
	if err := os.MkdirAll(c.cacheDir, 0o755); err != nil {
		return fmt.Errorf("create cache dir: %w", err)
	}

	var entries []cacheEntry
	for _, imgPath := range imageFiles {
		// Only process JPEG files
		lower := strings.ToLower(imgPath)
		if !strings.HasSuffix(lower, ".jpg") && !strings.HasSuffix(lower, ".jpeg") {
			continue
		}

		exifData, err := ReadExif(imgPath)
		if err != nil {
			// Non-fatal — some images may not have EXIF
			continue
		}

		entry := cacheEntryFromExif(filepath.Base(imgPath), postSlug, exifData)
		entries = append(entries, entry)
	}

	data, err := yaml.Marshal(entries)
	if err != nil {
		return fmt.Errorf("marshal cache: %w", err)
	}

	header := []byte("---\n")
	return os.WriteFile(c.cachePath(postSlug), append(header, data...), 0o644)
}

// LoadOrGenerate loads from cache if fresh, otherwise regenerates.
func (c *Cache) LoadOrGenerate(postSlug string, imageFiles []string) ([]*model.ExifData, error) {
	if !c.IsStale(postSlug, imageFiles) {
		return c.Load(postSlug)
	}
	if err := c.Generate(postSlug, imageFiles); err != nil {
		return nil, err
	}
	return c.Load(postSlug)
}

// cacheEntry is the YAML-serializable form of EXIF data with image metadata.
type cacheEntry struct {
	ImageFilename  string   `yaml:"image_filename"`
	PostSlug       string   `yaml:"post_slug"`
	Lat            *float64 `yaml:"lat,omitempty"`
	Lon            *float64 `yaml:"lon,omitempty"`
	Altitude       *float64 `yaml:"altitude,omitempty"`
	FocalLength    *float64 `yaml:"focal_length,omitempty"`
	FocalLength35  *float64 `yaml:"focal_length_35,omitempty"`
	Crop           *float64 `yaml:"crop,omitempty"`
	Aperture       *float64 `yaml:"aperture,omitempty"`
	FocusDistance   *float64 `yaml:"focus_distance,omitempty"`
	Exposure       *float64 `yaml:"exposure,omitempty"`
	ExposureString string   `yaml:"exposure_string,omitempty"`
	ISO            *int     `yaml:"iso,omitempty"`
	Width          *int     `yaml:"width,omitempty"`
	Height         *int     `yaml:"height,omitempty"`
	Lens           string   `yaml:"lens,omitempty"`
	Camera         string   `yaml:"camera,omitempty"`
	LensName       string   `yaml:"lens_name,omitempty"`
	CameraName     string   `yaml:"camera_name,omitempty"`
	Time           string   `yaml:"time,omitempty"` // RFC3339
	Make           string   `yaml:"make,omitempty"`
	WhiteBalance   string   `yaml:"white_balance,omitempty"`
	MeteringMode   string   `yaml:"metering_mode,omitempty"`
	Flash          string   `yaml:"flash,omitempty"`
	Orientation    int      `yaml:"orientation,omitempty"`
	ColorSpace     string   `yaml:"color_space,omitempty"`
	Software       string   `yaml:"software,omitempty"`
	GPSSpeed        *float64 `yaml:"gps_speed,omitempty"`
	GPSBearing      *float64 `yaml:"gps_bearing,omitempty"`
	TimezoneOffset  string   `yaml:"timezone_offset,omitempty"`
	ExposureProgram string   `yaml:"exposure_program,omitempty"`
	ExposureBias    *float64 `yaml:"exposure_bias,omitempty"`
	LensMinFocal    *float64 `yaml:"lens_min_focal,omitempty"`
	LensMaxFocal    *float64 `yaml:"lens_max_focal,omitempty"`
	LensMinFStop    *float64 `yaml:"lens_min_fstop,omitempty"`
	LensMaxFStop    *float64 `yaml:"lens_max_fstop,omitempty"`
	LensSpecStr     string   `yaml:"lens_spec_str,omitempty"`
	GPSMapDatum     string   `yaml:"gps_map_datum,omitempty"`
}

func cacheEntryFromExif(imageFilename, postSlug string, d *model.ExifData) cacheEntry {
	e := cacheEntry{
		ImageFilename:  imageFilename,
		PostSlug:       postSlug,
		Lat:            d.Lat,
		Lon:            d.Lon,
		Altitude:       d.Altitude,
		FocalLength:    d.FocalLength,
		FocalLength35:  d.FocalLength35,
		Crop:           d.Crop,
		Aperture:       d.Aperture,
		FocusDistance:   d.FocusDistance,
		Exposure:       d.Exposure,
		ExposureString: d.ExposureString,
		ISO:            d.ISO,
		Width:          d.Width,
		Height:         d.Height,
		Lens:           d.Lens,
		Camera:         d.Camera,
		LensName:       d.LensName,
		CameraName:     d.CameraName,
		Make:           d.Make,
		WhiteBalance:   d.WhiteBalance,
		MeteringMode:   d.MeteringMode,
		Flash:          d.Flash,
		Orientation:    d.Orientation,
		ColorSpace:     d.ColorSpace,
		Software:       d.Software,
		GPSSpeed:        d.GPSSpeed,
		GPSBearing:      d.GPSBearing,
		TimezoneOffset:  d.TimezoneOffset,
		ExposureProgram: d.ExposureProgram,
		ExposureBias:    d.ExposureBias,
		LensMinFocal:    d.LensMinFocal,
		LensMaxFocal:    d.LensMaxFocal,
		LensMinFStop:    d.LensMinFStop,
		LensMaxFStop:    d.LensMaxFStop,
		LensSpecStr:     d.LensSpecStr,
		GPSMapDatum:     d.GPSMapDatum,
	}
	if d.Time != nil {
		e.Time = d.Time.Format("2006-01-02T15:04:05-07:00")
	}
	return e
}

func (e *cacheEntry) toExifData() *model.ExifData {
	d := &model.ExifData{
		Lat:            e.Lat,
		Lon:            e.Lon,
		Altitude:       e.Altitude,
		FocalLength:    e.FocalLength,
		FocalLength35:  e.FocalLength35,
		Crop:           e.Crop,
		Aperture:       e.Aperture,
		FocusDistance:   e.FocusDistance,
		Exposure:       e.Exposure,
		ExposureString: e.ExposureString,
		ISO:            e.ISO,
		Width:          e.Width,
		Height:         e.Height,
		Lens:           e.Lens,
		Camera:         e.Camera,
		LensName:       e.LensName,
		CameraName:     e.CameraName,
		Make:           e.Make,
		WhiteBalance:   e.WhiteBalance,
		MeteringMode:   e.MeteringMode,
		Flash:          e.Flash,
		Orientation:    e.Orientation,
		ColorSpace:     e.ColorSpace,
		Software:       e.Software,
		GPSSpeed:        e.GPSSpeed,
		GPSBearing:      e.GPSBearing,
		TimezoneOffset:  e.TimezoneOffset,
		ExposureProgram: e.ExposureProgram,
		ExposureBias:    e.ExposureBias,
		LensMinFocal:    e.LensMinFocal,
		LensMaxFocal:    e.LensMaxFocal,
		LensMinFStop:    e.LensMinFStop,
		LensMaxFStop:    e.LensMaxFStop,
		LensSpecStr:     e.LensSpecStr,
		GPSMapDatum:     e.GPSMapDatum,
	}
	if e.Time != "" {
		if t, err := parseTimeString(e.Time); err == nil {
			d.Time = &t
		}
	}
	return d
}

func parseTimeString(s string) (time.Time, error) {
	// Try RFC3339 first
	t, err := time.Parse(time.RFC3339, s)
	if err == nil {
		return t, nil
	}
	// Try the Crystal-compatible format
	t, err = time.Parse("2006-01-02 15:04:05.000000000-07:00", s)
	if err == nil {
		return t, nil
	}
	return time.Parse("2006-01-02 15:04:05 -07:00", s)
}
