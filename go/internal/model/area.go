package model

import "fmt"

// AreaType identifies the administrative/geographic level of an area.
type AreaType int

const (
	AreaTypeTown AreaType = iota
	AreaTypeCounty
	AreaTypeVoivodeship
	AreaTypeMesoRegion
	AreaTypeMacroRegion
	AreaTypeExternal
)

// String returns the English name of the area type.
func (t AreaType) String() string {
	switch t {
	case AreaTypeTown:
		return "town"
	case AreaTypeCounty:
		return "county"
	case AreaTypeVoivodeship:
		return "voivodeship"
	case AreaTypeMesoRegion:
		return "meso_region"
	case AreaTypeMacroRegion:
		return "macro_region"
	case AreaTypeExternal:
		return "external"
	default:
		return fmt.Sprintf("unknown(%d)", int(t))
	}
}

// NominativeSlug returns the Polish nominative case used in area show URLs.
// Example: /gmina/slug.html
func (t AreaType) NominativeSlug() string {
	switch t {
	case AreaTypeTown:
		return "gmina"
	case AreaTypeCounty:
		return "powiat"
	case AreaTypeVoivodeship:
		return "wojewodztwo"
	case AreaTypeMesoRegion:
		// Crystal (data/src/models/area_type.cr) uses "region"/"obszar" for the
		// physico-geographic show pages — these are the production URLs, so the
		// Go rewrite must match them exactly (e.g. /region/bory_tucholskie.html).
		return "region"
	case AreaTypeMacroRegion:
		return "obszar"
	case AreaTypeExternal:
		return "zagranica"
	default:
		return "unknown"
	}
}

// PolishName returns the Polish nominative singular name for display
// (e.g. "gmina", "powiat", "województwo"). Used in meta descriptions and
// headings. Mirrors Crystal's AreaType#polish_nominative.
func (t AreaType) PolishName() string {
	switch t {
	case AreaTypeTown:
		return "gmina"
	case AreaTypeCounty:
		return "powiat"
	case AreaTypeVoivodeship:
		return "województwo"
	case AreaTypeMesoRegion:
		return "region"
	case AreaTypeMacroRegion:
		return "obszar"
	case AreaTypeExternal:
		return "zagranica"
	default:
		return "unknown"
	}
}

// GenitiveSlug returns the Polish genitive case used in post-list/gallery URLs.
// Example: /wpisy-dla/gminy/slug.html
func (t AreaType) GenitiveSlug() string {
	switch t {
	case AreaTypeTown:
		return "gminy"
	case AreaTypeCounty:
		return "powiatu"
	case AreaTypeVoivodeship:
		return "wojewodztwa"
	case AreaTypeMesoRegion:
		return "regionu"
	case AreaTypeMacroRegion:
		return "obszaru"
	case AreaTypeExternal:
		return "zagranica"
	default:
		return "unknown"
	}
}

// EnglishPlural returns the English plural form used in config file names.
func (t AreaType) EnglishPlural() string {
	switch t {
	case AreaTypeTown:
		return "towns"
	case AreaTypeCounty:
		return "counties"
	case AreaTypeVoivodeship:
		return "voivodeships"
	case AreaTypeMesoRegion:
		return "meso_regions"
	case AreaTypeMacroRegion:
		return "macro_regions"
	case AreaTypeExternal:
		return "external"
	default:
		return "unknown"
	}
}

// ConfigFilename returns the YAML config filename for this area type.
func (t AreaType) ConfigFilename() string {
	return t.EnglishPlural() + ".yml"
}

// ParseAreaType converts a string like "town" to an AreaType.
func ParseAreaType(s string) (AreaType, bool) {
	switch s {
	case "town":
		return AreaTypeTown, true
	case "county":
		return AreaTypeCounty, true
	case "voivodeship":
		return AreaTypeVoivodeship, true
	case "meso_region":
		return AreaTypeMesoRegion, true
	case "macro_region":
		return AreaTypeMacroRegion, true
	case "external":
		return AreaTypeExternal, true
	default:
		return 0, false
	}
}

// AllAreaTypes returns all area types in order.
func AllAreaTypes() []AreaType {
	return []AreaType{
		AreaTypeTown, AreaTypeCounty, AreaTypeVoivodeship,
		AreaTypeMesoRegion, AreaTypeMacroRegion,
	}
}

// BBox is an axis-aligned bounding box.
type BBox struct {
	South float64 `yaml:"south"`
	North float64 `yaml:"north"`
	West  float64 `yaml:"west"`
	East  float64 `yaml:"east"`
}

// Contains checks if a point is inside the bounding box.
func (b BBox) Contains(lat, lon float64) bool {
	return lat >= b.South && lat <= b.North && lon >= b.West && lon <= b.East
}

// Center returns the center point of the bounding box.
func (b BBox) Center() LatLon {
	return LatLon{
		Lat: (b.South + b.North) / 2,
		Lon: (b.West + b.East) / 2,
	}
}

// Area represents any administrative or geographic area (town, county, voivodeship, region).
type Area struct {
	Slug            string `yaml:"slug"`
	Name            string `yaml:"name"`
	Code            string `yaml:"code"`
	VoivodeshipSlug string `yaml:"voivodeship"`
	BBox            *BBox  `yaml:"bbox"`
	Type            AreaType
}

// AreaMapKey builds a map key from area type and slug (e.g., "town:pobiedziska").
// Used internally for map indexing; prefer 2-param lookup methods on SiteData.
func AreaMapKey(areaType AreaType, slug string) string {
	return areaType.String() + ":" + slug
}

// MapKey returns this area's map key for indexing.
func (a *Area) MapKey() string {
	return AreaMapKey(a.Type, a.Slug)
}
