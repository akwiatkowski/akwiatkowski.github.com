// Package exif reads EXIF metadata from JPEG files and manages per-post caches.
package exif

import (
	"fmt"
	"math"
	"strings"
	"time"

	exiflib "github.com/dsoprea/go-exif/v3"
	exifcommon "github.com/dsoprea/go-exif/v3/common"

	"odkrywajac/internal/model"
)

// ReadExif extracts EXIF data from a JPEG file.
// Tolerant of malformed tags — extracts whatever is available.
func ReadExif(imagePath string) (*model.ExifData, error) {
	rawExif, err := exiflib.SearchFileAndExtractExif(imagePath)
	if err != nil {
		return nil, fmt.Errorf("extract exif: %w", err)
	}

	entries, _, err := exiflib.GetFlatExifDataUniversalSearch(rawExif, nil, true)
	if err != nil {
		return nil, fmt.Errorf("parse exif: %w", err)
	}

	data := &model.ExifData{}
	tagMap := buildTagMap(entries)

	// GPS
	data.Lat, data.Lon = extractGPS(tagMap)
	data.Altitude = getFirstRational(tagMap, "IFD/GPSInfo", "GPSAltitude")

	// Equipment — read early so camera model is available for crop factor lookup
	data.Camera = getStringVal(tagMap, "IFD", "Model")
	data.CameraName = cleanEquipmentName(data.Camera)
	data.Make = getStringVal(tagMap, "IFD", "Make")
	data.Lens = getStringVal(tagMap, "IFD/Exif", "LensModel")
	data.LensName = cleanEquipmentName(data.Lens)

	// Focal length
	data.FocalLength = getFirstRational(tagMap, "IFD/Exif", "FocalLength")
	if v := getFirstShort(tagMap, "IFD/Exif", "FocalLengthIn35mmFilm"); v != nil {
		f := float64(*v)
		data.FocalLength35 = &f
	}

	// Crop factor: compute from FocalLength35/FocalLength if both are available,
	// otherwise look up the known crop factor for this camera model.
	if data.FocalLength != nil && data.FocalLength35 != nil && *data.FocalLength > 0 {
		crop := *data.FocalLength35 / *data.FocalLength
		crop = math.Round(crop*10) / 10
		data.Crop = &crop
	} else if data.FocalLength35 == nil && data.FocalLength != nil && *data.FocalLength > 0 {
		// FocalLengthIn35mmFilm tag missing — compute from known sensor crop factor.
		// Many cameras (OM System, newer Olympus) don't write this tag.
		if crop, ok := knownCropFactor(data.Camera); ok {
			fl35 := math.Round(*data.FocalLength * crop)
			data.FocalLength35 = &fl35
			data.Crop = &crop
		}
	}

	// Aperture
	data.Aperture = getFirstRational(tagMap, "IFD/Exif", "FNumber")

	// Exposure
	data.Exposure = getFirstRational(tagMap, "IFD/Exif", "ExposureTime")
	if data.Exposure != nil {
		data.ExposureString = formatExposure(*data.Exposure)
	}

	// ISO
	data.ISO = getFirstShort(tagMap, "IFD/Exif", "ISOSpeedRatings")

	// Dimensions
	data.Width = getFirstLong(tagMap, "IFD/Exif", "PixelXDimension")
	data.Height = getFirstLong(tagMap, "IFD/Exif", "PixelYDimension")
	if data.Width == nil {
		data.Width = getFirstLong(tagMap, "IFD", "ImageWidth")
	}
	if data.Height == nil {
		data.Height = getFirstLong(tagMap, "IFD", "ImageLength")
	}

	// Time — combine DateTimeOriginal with OffsetTimeOriginal for timezone-aware timestamps.
	// OffsetTimeOriginal (e.g., "+01:00") is stored separately for golden hour detection.
	data.TimezoneOffset = getStringVal(tagMap, "IFD/Exif", "OffsetTimeOriginal")
	if ts := getStringVal(tagMap, "IFD/Exif", "DateTimeOriginal"); ts != "" {
		if data.TimezoneOffset != "" {
			// Parse with timezone: "2022:12:18 15:15:23" + "+01:00" → full RFC3339
			combined := ts + data.TimezoneOffset
			if t, err := time.Parse("2006:01:02 15:04:05-07:00", combined); err == nil {
				data.Time = &t
			}
		}
		if data.Time == nil {
			// Fallback: parse without timezone (older cameras without OffsetTime)
			if t, err := time.Parse("2006:01:02 15:04:05", ts); err == nil {
				data.Time = &t
			}
		}
	}

	// Orientation
	if o := getFirstShort(tagMap, "IFD", "Orientation"); o != nil {
		data.Orientation = *o
	}

	// White balance
	if wb := getFirstShort(tagMap, "IFD/Exif", "WhiteBalance"); wb != nil {
		switch *wb {
		case 0:
			data.WhiteBalance = "auto"
		case 1:
			data.WhiteBalance = "manual"
		}
	}

	// Metering mode
	if mm := getFirstShort(tagMap, "IFD/Exif", "MeteringMode"); mm != nil {
		switch *mm {
		case 1:
			data.MeteringMode = "average"
		case 2:
			data.MeteringMode = "center-weighted"
		case 3:
			data.MeteringMode = "spot"
		case 5:
			data.MeteringMode = "evaluative"
		case 6:
			data.MeteringMode = "partial"
		}
	}

	// Flash
	if flash := getFirstShort(tagMap, "IFD/Exif", "Flash"); flash != nil {
		if *flash&1 == 0 {
			data.Flash = "not fired"
		} else {
			data.Flash = "fired"
		}
	}

	// Color space
	if cs := getFirstShort(tagMap, "IFD/Exif", "ColorSpace"); cs != nil {
		switch *cs {
		case 1:
			data.ColorSpace = "sRGB"
		case 2:
			data.ColorSpace = "AdobeRGB"
		}
	}

	// Software
	data.Software = getStringVal(tagMap, "IFD", "Software")

	// Exposure program — how the camera chose exposure settings.
	if ep := getFirstShort(tagMap, "IFD/Exif", "ExposureProgram"); ep != nil {
		switch *ep {
		case 1:
			data.ExposureProgram = "manual"
		case 2:
			data.ExposureProgram = "program"
		case 3:
			data.ExposureProgram = "aperture_priority"
		case 4:
			data.ExposureProgram = "shutter_priority"
		case 5:
			data.ExposureProgram = "creative" // biased toward depth of field
		case 6:
			data.ExposureProgram = "action" // biased toward fast shutter
		}
	}

	// Exposure bias (compensation) in EV — SRATIONAL tag.
	data.ExposureBias = getFirstSignedRational(tagMap, "IFD/Exif", "ExposureBiasValue")

	// Lens specification — 4 rationals: min focal, max focal, min f-stop at wide, min f-stop at tele.
	// Useful as lens identification fallback when LensModel is missing (Pentax cameras).
	extractLensSpec(tagMap, data)

	// GPS map datum — coordinate reference system (usually "WGS-84").
	data.GPSMapDatum = getStringVal(tagMap, "IFD/GPSInfo", "GPSMapDatum")

	return data, nil
}

// --- Tag Map: fast lookup of EXIF entries by IFD path + tag name ---
//
// dsoprea/go-exif returns a flat list of ExifTag entries. We index them
// into a map for O(1) access by (ifdPath, tagName). IFD paths follow the
// EXIF standard: "IFD" for main, "IFD/Exif" for EXIF sub-IFD,
// "IFD/GPSInfo" for GPS data.

type tagKey struct {
	ifdPath string
	tagName string
}

func buildTagMap(entries []exiflib.ExifTag) map[tagKey]exiflib.ExifTag {
	m := make(map[tagKey]exiflib.ExifTag, len(entries))
	for _, e := range entries {
		key := tagKey{ifdPath: e.IfdPath, tagName: e.TagName}
		m[key] = e
	}
	return m
}

func findTag(m map[tagKey]exiflib.ExifTag, ifdPath, tagName string) (exiflib.ExifTag, bool) {
	e, ok := m[tagKey{ifdPath: ifdPath, tagName: tagName}]
	return e, ok
}

// --- GPS extraction ---
//
// GPS coordinates are stored as three Rational values (degrees, minutes, seconds)
// with a separate N/S/E/W reference tag. We combine them into decimal degrees.

func extractGPS(m map[tagKey]exiflib.ExifTag) (*float64, *float64) {
	latTag, hasLat := findTag(m, "IFD/GPSInfo", "GPSLatitude")
	latRefTag, hasLatRef := findTag(m, "IFD/GPSInfo", "GPSLatitudeRef")
	lonTag, hasLon := findTag(m, "IFD/GPSInfo", "GPSLongitude")
	lonRefTag, hasLonRef := findTag(m, "IFD/GPSInfo", "GPSLongitudeRef")

	if !hasLat || !hasLon || !hasLatRef || !hasLonRef {
		return nil, nil
	}

	lat := dmsToDecimal(latTag.Value)
	lon := dmsToDecimal(lonTag.Value)

	if lat == nil || lon == nil {
		return nil, nil
	}

	latRef := fmt.Sprintf("%v", latRefTag.Value)
	lonRef := fmt.Sprintf("%v", lonRefTag.Value)
	if strings.Contains(latRef, "S") {
		*lat = -*lat
	}
	if strings.Contains(lonRef, "W") {
		*lon = -*lon
	}

	return lat, lon
}

// dmsToDecimal converts GPS DMS (degrees/minutes/seconds) rationals to decimal degrees.
func dmsToDecimal(value any) *float64 {
	// The value is typically []exifcommon.Rational
	rats, ok := value.([]exifcommon.Rational)
	if !ok || len(rats) < 3 {
		return nil
	}
	deg := ratToFloat(rats[0])
	minVal := ratToFloat(rats[1])
	sec := ratToFloat(rats[2])
	result := deg + minVal/60 + sec/3600
	return &result
}

func ratToFloat(r exifcommon.Rational) float64 {
	if r.Denominator == 0 {
		return 0
	}
	return float64(r.Numerator) / float64(r.Denominator)
}

// --- Type-safe tag value extractors ---
//
// EXIF tag values come as typed slices ([]Rational, []uint16, []uint32, string).
// These helpers extract the first element with type assertion, returning nil
// if the tag is missing or has an unexpected type. Used by ReadExif to
// populate ExifData fields.

// getFirstRational extracts a rational EXIF tag (e.g., FocalLength, Aperture, ExposureTime).
func getFirstRational(m map[tagKey]exiflib.ExifTag, ifdPath, tagName string) *float64 {
	tag, ok := findTag(m, ifdPath, tagName)
	if !ok {
		return nil
	}
	if v, ok := tag.Value.([]exifcommon.Rational); ok {
		if len(v) > 0 {
			f := ratToFloat(v[0])
			return &f
		}
	}
	return nil
}

// getFirstShort extracts a uint16/uint32 EXIF tag (e.g., ISO, Orientation, Flash).
func getFirstShort(m map[tagKey]exiflib.ExifTag, ifdPath, tagName string) *int {
	tag, ok := findTag(m, ifdPath, tagName)
	if !ok {
		return nil
	}
	switch v := tag.Value.(type) {
	case []uint16:
		if len(v) > 0 {
			i := int(v[0])
			return &i
		}
	case []uint32:
		if len(v) > 0 {
			i := int(v[0])
			return &i
		}
	}
	return nil
}

// getFirstLong extracts a uint32/uint16 EXIF tag (e.g., PixelXDimension, ImageWidth).
func getFirstLong(m map[tagKey]exiflib.ExifTag, ifdPath, tagName string) *int {
	tag, ok := findTag(m, ifdPath, tagName)
	if !ok {
		return nil
	}
	switch v := tag.Value.(type) {
	case []uint32:
		if len(v) > 0 {
			i := int(v[0])
			return &i
		}
	case []uint16:
		if len(v) > 0 {
			i := int(v[0])
			return &i
		}
	}
	return nil
}

// getFirstSignedRational extracts a signed rational EXIF tag (e.g., ExposureBiasValue).
// SRATIONAL values represent signed fractions, used for exposure compensation and brightness.
func getFirstSignedRational(m map[tagKey]exiflib.ExifTag, ifdPath, tagName string) *float64 {
	tag, ok := findTag(m, ifdPath, tagName)
	if !ok {
		return nil
	}
	if v, ok := tag.Value.([]exifcommon.SignedRational); ok {
		if len(v) > 0 {
			if v[0].Denominator == 0 {
				return nil
			}
			f := float64(v[0].Numerator) / float64(v[0].Denominator)
			f = math.Round(f*10) / 10 // round to 1 decimal
			return &f
		}
	}
	return nil
}

// getRationals extracts all rational values from an EXIF tag as a float64 slice.
// Used for multi-value tags like LensSpecification (4 rationals).
func getRationals(m map[tagKey]exiflib.ExifTag, ifdPath, tagName string) []float64 {
	tag, ok := findTag(m, ifdPath, tagName)
	if !ok {
		return nil
	}
	rats, ok := tag.Value.([]exifcommon.Rational)
	if !ok {
		return nil
	}
	result := make([]float64, len(rats))
	for i, r := range rats {
		result[i] = ratToFloat(r)
	}
	return result
}

// extractLensSpec reads the LensSpecification EXIF tag (4 rationals) and populates
// ExifData with min/max focal lengths, min f-stop values, and a formatted string.
// LensSpecification format: [minFocal, maxFocal, minFStopWide, minFStopTele].
// The formatted string (e.g., "12-100mm f/4.0" or "50mm f/1.8") can serve as a
// lens name fallback when LensModel is missing (Pentax cameras).
func extractLensSpec(m map[tagKey]exiflib.ExifTag, data *model.ExifData) {
	vals := getRationals(m, "IFD/Exif", "LensSpecification")
	if len(vals) < 4 {
		return
	}
	minFocal, maxFocal := vals[0], vals[1]
	minFStopWide, minFStopTele := vals[2], vals[3]

	if minFocal > 0 {
		data.LensMinFocal = &minFocal
	}
	if maxFocal > 0 {
		data.LensMaxFocal = &maxFocal
	}
	if minFStopWide > 0 {
		data.LensMinFStop = &minFStopWide
	}
	if minFStopTele > 0 {
		data.LensMaxFStop = &minFStopTele
	}

	data.LensSpecStr = formatLensSpec(minFocal, maxFocal, minFStopWide, minFStopTele)
}

// formatLensSpec builds a human-readable lens description from specification values.
// Examples: "12-100mm f/4.0", "50mm f/1.8", "28-75mm f/2.8-2.8".
func formatLensSpec(minFocal, maxFocal, minFStopWide, minFStopTele float64) string {
	if minFocal <= 0 {
		return ""
	}

	var focal string
	if minFocal == maxFocal || maxFocal <= 0 {
		focal = fmt.Sprintf("%gmm", minFocal)
	} else {
		focal = fmt.Sprintf("%g-%gmm", minFocal, maxFocal)
	}

	if minFStopWide <= 0 {
		return focal
	}

	var fstop string
	if minFStopWide == minFStopTele || minFStopTele <= 0 {
		fstop = fmt.Sprintf("f/%.1f", minFStopWide)
	} else {
		fstop = fmt.Sprintf("f/%.1f-%.1f", minFStopWide, minFStopTele)
	}

	return focal + " " + fstop
}

// getStringVal extracts a string EXIF tag (e.g., Camera Model, Lens, Software).
func getStringVal(m map[tagKey]exiflib.ExifTag, ifdPath, tagName string) string {
	tag, ok := findTag(m, ifdPath, tagName)
	if !ok {
		return ""
	}
	s := fmt.Sprintf("%v", tag.Value)
	s = strings.TrimRight(s, "\x00 ")
	return s
}

// formatExposure converts exposure time to a readable string.
func formatExposure(exp float64) string {
	if exp <= 0 {
		return ""
	}
	if exp >= 1 {
		return fmt.Sprintf("%.1f s", exp)
	}
	reciprocal := 1 / exp
	return fmt.Sprintf("1/%d s", int(math.Round(reciprocal)))
}

// knownCropFactor returns the sensor crop factor for a recognized camera model.
// Used to compute FocalLength35 = FocalLength × CropFactor when the camera
// doesn't write the FocalLengthIn35mmFilm EXIF tag.
//
// Crop factors by sensor size:
//   - Full frame (36×24mm): 1.0 — Sony A7 series
//   - APS-C (23.5×15.6mm): 1.5 — Pentax, Sony APS-C, Nikon DX
//   - Micro Four Thirds (17.3×13mm): 2.0 — Olympus, OM System, Panasonic
//   - 1/2.3" (6.17×4.55mm): 5.64 — GoPro, DJI Spark
func knownCropFactor(cameraModel string) (float64, bool) {
	cameraModel = strings.TrimSpace(cameraModel)
	if cameraModel == "" {
		return 0, false
	}

	// Exact match first — covers models in our camera dictionary
	if crop, ok := cameraCropFactors[cameraModel]; ok {
		return crop, true
	}

	// Prefix-based fallback for camera families
	upper := strings.ToUpper(cameraModel)
	switch {
	case strings.HasPrefix(upper, "E-M") || strings.HasPrefix(upper, "OM-"):
		return 2.0, true // Olympus / OM System — Micro Four Thirds
	case strings.HasPrefix(upper, "ILCE-"):
		return 1.0, true // Sony mirrorless — assume full frame
	case strings.HasPrefix(upper, "PENTAX"):
		return 1.5, true // Pentax APS-C
	}

	return 0, false
}

// cameraCropFactors maps specific camera models to their sensor crop factor.
// Only needed for cameras that don't write FocalLengthIn35mmFilm.
var cameraCropFactors = map[string]float64{
	// Micro Four Thirds (crop 2.0)
	"E-M1MarkII":  2.0,
	"E-M1MarkIII": 2.0,
	"E-M10MarkII": 2.0,
	"OM-1":        2.0,
	// Full frame (crop 1.0)
	"ILCE-7M3":  1.0,
	"ILCE-7R":   1.0,
	"ILCE-7RM3": 1.0,
	// APS-C (crop 1.5)
	"PENTAX K-S2":  1.5,
	"PENTAX K100D": 1.53, // Pentax K100D has a slightly larger APS-C sensor
	"PENTAX K-5":   1.5,
	// DJI drones — each has a specific sensor
	"FC1102":  1.0, // DJI Spark — already reports 35mm equiv in EXIF
	"FC3582":  1.0, // DJI Mini 3 Pro — already reports 35mm equiv
	"L2D-20c": 1.0, // DJI Mavic 3 — already reports 35mm equiv
	"FC4170":  1.0, // DJI Mavic 3 tele — already reports 35mm equiv
	// GoPro — very small sensor
	"Hero3-Black Edition": 5.64, // 1/2.3" sensor
}

// cleanEquipmentName strips manufacturer prefixes and extra whitespace.
func cleanEquipmentName(name string) string {
	name = strings.TrimSpace(name)
	for _, prefix := range []string{"OLYMPUS ", "Canon ", "NIKON ", "SONY ", "Panasonic ", "FUJIFILM "} {
		name = strings.TrimPrefix(name, prefix)
	}
	return name
}
