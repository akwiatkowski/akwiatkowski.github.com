package model

import "time"

// Photo represents a single photo with its metadata and EXIF data.
type Photo struct {
	ImageFilename string
	PostSlug      string
	Desc          string
	TagSlugs      []string // photo tag slugs ("good", "best", etc.)
	Points        int
	IsHeader      bool
	IsGallery     bool
	Exif          *ExifData
}

// HasGPS returns true if this photo has GPS coordinates.
func (p *Photo) HasGPS() bool {
	return p.Exif != nil && p.Exif.Lat != nil && p.Exif.Lon != nil
}

// ExifData holds EXIF metadata extracted from a JPEG file.
type ExifData struct {
	// GPS
	Lat      *float64 `yaml:"lat,omitempty"`
	Lon      *float64 `yaml:"lon,omitempty"`
	Altitude *float64 `yaml:"altitude,omitempty"`

	// Optics
	FocalLength   *float64 `yaml:"focal_length,omitempty"`
	FocalLength35 *float64 `yaml:"focal_length_35,omitempty"`
	Crop          *float64 `yaml:"crop,omitempty"`
	Aperture      *float64 `yaml:"aperture,omitempty"`
	FocusDistance  *float64 `yaml:"focus_distance,omitempty"`

	// Exposure
	Exposure       *float64 `yaml:"exposure,omitempty"`
	ExposureString string   `yaml:"exposure_string,omitempty"`
	ISO            *int     `yaml:"iso,omitempty"`

	// Dimensions
	Width  *int `yaml:"width,omitempty"`
	Height *int `yaml:"height,omitempty"`

	// Equipment
	Lens       string `yaml:"lens,omitempty"`
	Camera     string `yaml:"camera,omitempty"`
	LensName   string `yaml:"lens_name,omitempty"`
	CameraName string `yaml:"camera_name,omitempty"`

	// Timing
	Time *time.Time `yaml:"time,omitempty"`

	// Extended fields (beyond Crystal)
	Make         string   `yaml:"make,omitempty"`
	WhiteBalance string   `yaml:"white_balance,omitempty"`
	MeteringMode string   `yaml:"metering_mode,omitempty"`
	Flash        string   `yaml:"flash,omitempty"`
	Orientation  int      `yaml:"orientation,omitempty"`
	ColorSpace   string   `yaml:"color_space,omitempty"`
	Software     string   `yaml:"software,omitempty"`
	GPSSpeed     *float64 `yaml:"gps_speed,omitempty"`
	GPSBearing   *float64 `yaml:"gps_bearing,omitempty"`

	// Timezone from OffsetTimeOriginal (e.g., "+01:00", "+02:00").
	// Enables UTC conversion and golden hour detection.
	TimezoneOffset string `yaml:"timezone_offset,omitempty"`

	// Exposure program: "manual", "aperture_priority", "shutter_priority", "program", "auto".
	ExposureProgram string `yaml:"exposure_program,omitempty"`

	// Exposure compensation in EV (e.g., -0.7, +1.3, 0.0).
	ExposureBias *float64 `yaml:"exposure_bias,omitempty"`

	// Lens specification from EXIF LensSpecification tag (4 rationals).
	// Useful as fallback when LensModel is missing (e.g., Pentax).
	LensMinFocal    *float64 `yaml:"lens_min_focal,omitempty"`    // minimum focal length (mm)
	LensMaxFocal    *float64 `yaml:"lens_max_focal,omitempty"`    // maximum focal length (mm)
	LensMinFStop    *float64 `yaml:"lens_min_fstop,omitempty"`    // widest aperture at min focal
	LensMaxFStop    *float64 `yaml:"lens_max_fstop,omitempty"`    // widest aperture at max focal
	LensSpecStr     string   `yaml:"lens_spec_str,omitempty"`     // formatted: "12-100mm f/4.0" or "50mm f/1.8"

	// GPS coordinate reference system (e.g., "WGS-84").
	GPSMapDatum string `yaml:"gps_map_datum,omitempty"`
}
