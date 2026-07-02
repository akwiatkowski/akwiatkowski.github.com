package exif

import (
	"fmt"
	"log/slog"
	"math"
	"os"
	"path/filepath"
	"strings"
	"time"

	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

// cameraNames maps raw EXIF camera model strings to human-readable names.
// Matches Crystal's ExifEntity::CAMERA_NAMES.
var cameraNames = map[string]string{
	"ILCE-7M3":            "Sony A7 III",
	"ILCE-7R":             "Sony A7R",
	"ILCE-7RM3":           "Sony A7R III",
	"E-M1MarkII":          "Olympus M1m2",
	"E-M1MarkIII":         "Olympus M1m3",
	"E-M10MarkII":         "Olympus M10m2",
	"Hero3-Black Edition": "Gopro 3 Black",
	"PENTAX K-S2":         "Pentax K-S2",
	"PENTAX K100D":        "Pentax K100D",
	"PENTAX K-5":          "Pentax K-5",
	"FC1102":              "DJI Spark",
	"Redmi Note 3":        "Xiaomi Redmi Note 3",
	"FC3582":              "DJI Mini 3 Pro",
	"OM-1":                "OM System OM-1",
	"iPhone 13 Pro":       "iPhone 13 Pro",
	"L2D-20c":             "DJI Mavic 3 (ekw. 24mm)",
	"FC4170":              "DJI Mavic 3 (tele ekw. 160mm)",
}

// lensNames maps raw EXIF lens model strings to human-readable names.
// Matches Crystal's ExifEntity::LENS_NAMES.
var lensNames = map[string]string{
	"FE 85mm F1.8":         "Sony 85mm f1.8",
	"E 28-75mm F2.8-2.8":   "Tamron 28-75mm f2.8",
	"E 70-180mm F2.8 A056": "Tamron 70-180mm f2.8",
	"100-400mm F5-6.3 DG DN OS | Contemporary 020":  "Sigma 100-400mm f5-6.3",
	"LUMIX G VARIO 14-140/F3.5-5.6":                 "Lumix 14-140mm",
	"OLYMPUS M.12-100mm F4.0":                       "Olympus 12-100mm f4",
	"LUMIX G 20/F1.7 II":                            "Lumix 20mm f1.7",
	"M.40-150mm F2.8 + MC-14":                       "Olympus 40-150mm f2.8 + TC 1.4x",
	"M.40-150mm F2.8 + MC-20":                       "Olympus 40-150mm f2.8 + TC 2.0x",
	"E 20mm F2":                                     "Tokina 20mm f2",
	"OLYMPUS M.40-150mm F2.8":                       "Olympus 40-150mm f2.8",
	"OLYMPUS M.9-18mm F4.0-5.6":                     "Olympus 9-18mm",
	"OLYMPUS M.60mm F2.8 Macro":                     "Olympus 60mm Macro",
	"smc PENTAX-DA 16-45mm F4 ED AL":                "Pentax 16-45mm f4",
	"smc PENTAX-DA 15mm F4 ED AL Limited":           "Pentax 15mm f4",
	"OLYMPUS M.75-300mm F4.8-6.7 II":                "Olympus 75-300mm",
	"Sigma 150-500mm F5-6.3 APO DG OS HSM":          "Sigma 150-500mm",
	"smc PENTAX-FA Macro 50mm F2.8":                 "Pentax 50mm Macro",
	"OLYMPUS M.25mm F1.2":                           "Olympus 25mm f1.2",
	"smc PENTAX-DA 70mm F2.4 Limited":               "Pentax 70mm f2.4",
	"smc PENTAX-DA 40mm F2.8 Limited":               "Pentax 40mm f2.8",
	"smc PENTAX-DA 35mm F2.4 AL":                    "Pentax 35mm f2.4",
	"OLYMPUS M.17mm F1.2":                           "Olympus 17mm f1.2",
	"LEICA DG SUMMILUX 25/F1.4":                     "Lumix 25mm f1.4",
	"Sigma Lens":                                    "Nieznane",
	"A Series Lens":                                 "Nieznane",
	"K or M Lens":                                   "Nieznane",
	"OLYMPUS M.75mm F1.8":                           "Olympus 75mm f1.8",
	"LEICA DG 8-18/F2.8-4.0":                        "Lumix 8-18mm",
	"OLYMPUS M.8mm F1.8":                            "Olympus 8mm f1.8",
	"105mm F1.4 DG HSM | Art 018":                   "Sigma 105mm f1.4",
	"OLYMPUS M.14-42mm F3.5-5.6 EZ":                 "Olympus 14-42mm Kit",
	"OLYMPUS M.14-42mm F3.5-5.6 II R":               "Olympus 14-42mm Kit",
	"Sigma 17-50/2.8":                               "Sigma 17-50mm f2.8",
	"Sigma 10-20":                                   "Sigma 10-20mm",
	"Pentax FA 50mm Macro":                          "Pentax 50mm f2.8",
	"Ports 55/1.2":                                  "Ports 55mm f1.2",
	"Sigma 18-200 old":                              "Sigma 18-200mm (old)",
	"Sigma 18-200 C":                                "Sigma 18-200mm C",
	"FE 70-200mm F2.8 GM OSS":                       "Sony GM 70-200mm f2.8",
	"----":                                          "Nieznane",
	"Pentax SMC-A 135/2.8":                          "Pentax 135mm f2.8",
	"M.300mm F4.0 + MC-14":                          "Olympus 300mm f4 + TC 1.4x",
	"M.300mm F4.0 + MC-20":                          "Olympus 300mm f4 + TC 2.0x",
	"OLYMPUS M.300mm F4.0":                          "Olympus 300mm f4",
	"OLYMPUS M.100-400mm F5.0-6.3":                  "Olympus 100-400mm f5-6.3",
	"OLYMPUS M.7-14mm F2.8":                         "Olympus 7-14mm f2.8",
	"OLYMPUS M.8-25mm F4.0":                         "Olympus 8-25mm f4",
	"85mm F1.4 DG DN | Art 020":                     "Sigma 85mm f1.4",
	"OM 8-25mm F4.0":                                "Olympus 8-25mm f4",
	"iPhone 13 Pro back triple camera 9mm f/2.8":    "Tele 9mm f2.8 (ekw. 77mm)",
	"iPhone 13 Pro back triple camera 1.57mm f/1.8": "Szeroki 1.57mm (ekw. 13mm)",
	"OM 90mm F3.5":                                  "Olympus 90mm Macro",
	"Sigma 55-200mm F4-5.6 DC":                      "Sigma 55-200mm f4-5.6",
}

// resolveCameraName maps raw EXIF camera string to a human-readable name.
// Logs a warning if the camera is not in the dictionary.
func resolveCameraName(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if name, ok := cameraNames[raw]; ok {
		return name
	}
	slog.Warn("Unknown camera model, add to exif/cache.go cameraNames", "camera", raw)
	return raw
}

// resolveLensName maps raw EXIF lens string to a human-readable name.
// Logs a warning if the lens is not in the dictionary.
func resolveLensName(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if name, ok := lensNames[raw]; ok {
		return name
	}
	slog.Warn("Unknown lens model, add to exif/cache.go lensNames", "lens", raw)
	return raw
}

// Cache manages per-post EXIF cache files at cacheDir/{post_slug}.yml.
type Cache struct {
	cacheDir string
}

// NewCache creates a new EXIF cache manager.
// cacheDir should be the full path to the directory containing per-post YAML files
// (e.g. env/dev/cache-go/exifs/).
func NewCache(cacheDir string) *Cache {
	return &Cache{cacheDir: cacheDir}
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

// LoadMap reads cached EXIF data for a post and returns it indexed by image filename.
// This is the preferred method when looking up EXIF data for specific photos,
// since the cache stores one entry per image file.
func (c *Cache) LoadMap(postSlug string) (map[string]*model.ExifData, error) {
	data, err := os.ReadFile(c.cachePath(postSlug))
	if err != nil {
		return nil, fmt.Errorf("read cache %s: %w", postSlug, err)
	}

	var entries []cacheEntry
	if err := yaml.Unmarshal(data, &entries); err != nil {
		return nil, fmt.Errorf("parse cache %s: %w", postSlug, err)
	}

	result := make(map[string]*model.ExifData, len(entries))
	for _, entry := range entries {
		result[entry.ImageFilename] = entry.toExifData()
	}
	return result, nil
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

// LoadMapForPost loads EXIF data for a post, using per-post staleness checking.
// If the cache is fresh, reads from it. If stale or missing, regenerates from
// raw images in imageDir and writes the new cache file.
// Returns an empty map if the directory doesn't exist or has no images.
func (c *Cache) LoadMapForPost(postSlug string, imageDir string) (map[string]*model.ExifData, error) {
	imagePaths := ListImagePaths(imageDir)

	// Cache is fresh — read directly
	if !c.IsStale(postSlug, imagePaths) {
		return c.LoadMap(postSlug)
	}

	// No images — nothing to generate
	if len(imagePaths) == 0 {
		return make(map[string]*model.ExifData), nil
	}

	// Stale or missing — regenerate from raw images
	if err := c.Generate(postSlug, imagePaths); err != nil {
		return nil, fmt.Errorf("generate exif cache for %s: %w", postSlug, err)
	}
	return c.LoadMap(postSlug)
}

// ListImagePaths returns full paths of image files (JPEG/PNG) in a directory.
// Returns nil if the directory doesn't exist.
func ListImagePaths(dir string) []string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}

	var paths []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		lower := strings.ToLower(entry.Name())
		if strings.HasSuffix(lower, ".jpg") || strings.HasSuffix(lower, ".jpeg") || strings.HasSuffix(lower, ".png") {
			paths = append(paths, filepath.Join(dir, entry.Name()))
		}
	}
	return paths
}

// cacheEntry is the YAML-serializable form of EXIF data with image metadata.
type cacheEntry struct {
	ImageFilename   string   `yaml:"image_filename"`
	PostSlug        string   `yaml:"post_slug"`
	Lat             *float64 `yaml:"lat,omitempty"`
	Lon             *float64 `yaml:"lon,omitempty"`
	Altitude        *float64 `yaml:"altitude,omitempty"`
	FocalLength     *float64 `yaml:"focal_length,omitempty"`
	FocalLength35   *float64 `yaml:"focal_length_35,omitempty"`
	Crop            *float64 `yaml:"crop,omitempty"`
	Aperture        *float64 `yaml:"aperture,omitempty"`
	FocusDistance   *float64 `yaml:"focus_distance,omitempty"`
	Exposure        *float64 `yaml:"exposure,omitempty"`
	ExposureString  string   `yaml:"exposure_string,omitempty"`
	ISO             *int     `yaml:"iso,omitempty"`
	Width           *int     `yaml:"width,omitempty"`
	Height          *int     `yaml:"height,omitempty"`
	Lens            string   `yaml:"lens,omitempty"`
	Camera          string   `yaml:"camera,omitempty"`
	LensName        string   `yaml:"lens_name,omitempty"`
	CameraName      string   `yaml:"camera_name,omitempty"`
	Time            string   `yaml:"time,omitempty"` // RFC3339
	Make            string   `yaml:"make,omitempty"`
	WhiteBalance    string   `yaml:"white_balance,omitempty"`
	MeteringMode    string   `yaml:"metering_mode,omitempty"`
	Flash           string   `yaml:"flash,omitempty"`
	Orientation     int      `yaml:"orientation,omitempty"`
	ColorSpace      string   `yaml:"color_space,omitempty"`
	Software        string   `yaml:"software,omitempty"`
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
		ImageFilename:   imageFilename,
		PostSlug:        postSlug,
		Lat:             d.Lat,
		Lon:             d.Lon,
		Altitude:        d.Altitude,
		FocalLength:     d.FocalLength,
		FocalLength35:   d.FocalLength35,
		Crop:            d.Crop,
		Aperture:        d.Aperture,
		FocusDistance:   d.FocusDistance,
		Exposure:        d.Exposure,
		ExposureString:  d.ExposureString,
		ISO:             d.ISO,
		Width:           d.Width,
		Height:          d.Height,
		Lens:            d.Lens,
		Camera:          d.Camera,
		LensName:        d.LensName,
		CameraName:      d.CameraName,
		Make:            d.Make,
		WhiteBalance:    d.WhiteBalance,
		MeteringMode:    d.MeteringMode,
		Flash:           d.Flash,
		Orientation:     d.Orientation,
		ColorSpace:      d.ColorSpace,
		Software:        d.Software,
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
	// Always resolve human-readable names from the dictionary using raw EXIF strings.
	// The dictionary takes precedence; if not found, fall back to the cleaned name.
	cameraName := resolveCameraName(e.Camera)
	if cameraName == e.Camera && e.CameraName != "" {
		// Not in dictionary — use the cleaned name from the cache
		cameraName = e.CameraName
	}
	// Resolve lens name: dictionary lookup → cleaned name → focal-length inference.
	// Pentax cameras don't write LensModel in standard EXIF (only in MakerNotes),
	// so we infer the lens from (camera, focal_length) when the field is empty.
	rawLens := e.Lens
	if rawLens == "" && e.FocalLength != nil && e.Camera != "" {
		if inferred, ok := InferLensName(e.Camera, *e.FocalLength); ok {
			rawLens = inferred
		}
	}
	lensName := resolveLensName(rawLens)
	if lensName == rawLens && e.LensName != "" {
		// Not in dictionary — use the cleaned name from the cache
		lensName = e.LensName
	}

	d := &model.ExifData{
		Lat:             e.Lat,
		Lon:             e.Lon,
		Altitude:        e.Altitude,
		FocalLength:     e.FocalLength,
		FocalLength35:   e.FocalLength35,
		Crop:            e.Crop,
		Aperture:        e.Aperture,
		FocusDistance:   e.FocusDistance,
		Exposure:        e.Exposure,
		ExposureString:  e.ExposureString,
		ISO:             e.ISO,
		Width:           e.Width,
		Height:          e.Height,
		Lens:            rawLens,
		Camera:          e.Camera,
		LensName:        lensName,
		CameraName:      cameraName,
		Make:            e.Make,
		WhiteBalance:    e.WhiteBalance,
		MeteringMode:    e.MeteringMode,
		Flash:           e.Flash,
		Orientation:     e.Orientation,
		ColorSpace:      e.ColorSpace,
		Software:        e.Software,
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

	// Compute FocalLength35 from FocalLength × CropFactor if the EXIF tag was missing.
	// This covers cameras that don't write FocalLengthIn35mmFilm (OM System, newer Olympus).
	if d.FocalLength35 == nil && d.FocalLength != nil && *d.FocalLength > 0 {
		if crop, ok := knownCropFactor(d.Camera); ok {
			fl35 := math.Round(*d.FocalLength * crop)
			d.FocalLength35 = &fl35
			d.Crop = &crop
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
