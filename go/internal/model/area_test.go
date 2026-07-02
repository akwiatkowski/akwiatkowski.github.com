package model

import "testing"

func TestAreaTypeString(t *testing.T) {
	tests := []struct {
		at   AreaType
		want string
	}{
		{AreaTypeTown, "town"},
		{AreaTypeCounty, "county"},
		{AreaTypeVoivodeship, "voivodeship"},
		{AreaTypeMesoRegion, "meso_region"},
		{AreaTypeMacroRegion, "macro_region"},
	}
	for _, tt := range tests {
		if got := tt.at.String(); got != tt.want {
			t.Errorf("AreaType(%d).String() = %q, want %q", tt.at, got, tt.want)
		}
	}
}

func TestAreaTypeNominativeSlug(t *testing.T) {
	tests := []struct {
		at   AreaType
		want string
	}{
		{AreaTypeTown, "gmina"},
		{AreaTypeCounty, "powiat"},
		{AreaTypeVoivodeship, "wojewodztwo"},
		{AreaTypeMesoRegion, "region"},
		{AreaTypeMacroRegion, "obszar"},
	}
	for _, tt := range tests {
		if got := tt.at.NominativeSlug(); got != tt.want {
			t.Errorf("NominativeSlug() = %q, want %q", got, tt.want)
		}
	}
}

func TestAreaTypeGenitiveSlug(t *testing.T) {
	tests := []struct {
		at   AreaType
		want string
	}{
		{AreaTypeTown, "gminy"},
		{AreaTypeCounty, "powiatu"},
		{AreaTypeVoivodeship, "wojewodztwa"},
		{AreaTypeMesoRegion, "regionu"},
		{AreaTypeMacroRegion, "obszaru"},
	}
	for _, tt := range tests {
		if got := tt.at.GenitiveSlug(); got != tt.want {
			t.Errorf("GenitiveSlug() = %q, want %q", got, tt.want)
		}
	}
}

func TestAreaTypeConfigFilename(t *testing.T) {
	if got := AreaTypeTown.ConfigFilename(); got != "towns.yml" {
		t.Errorf("ConfigFilename() = %q, want towns.yml", got)
	}
	if got := AreaTypeMesoRegion.ConfigFilename(); got != "meso_regions.yml" {
		t.Errorf("ConfigFilename() = %q, want meso_regions.yml", got)
	}
}

func TestParseAreaType(t *testing.T) {
	at, ok := ParseAreaType("town")
	if !ok || at != AreaTypeTown {
		t.Errorf("ParseAreaType(town) = %v, %v", at, ok)
	}

	_, ok = ParseAreaType("invalid")
	if ok {
		t.Error("ParseAreaType(invalid) should return false")
	}
}

func TestBBoxContains(t *testing.T) {
	bbox := BBox{South: 50.0, North: 51.0, West: 16.0, East: 17.0}

	if !bbox.Contains(50.5, 16.5) {
		t.Error("center point should be inside")
	}
	if bbox.Contains(49.0, 16.5) {
		t.Error("point south should be outside")
	}
	if bbox.Contains(50.5, 18.0) {
		t.Error("point east should be outside")
	}
}

func TestBBoxCenter(t *testing.T) {
	bbox := BBox{South: 50.0, North: 52.0, West: 16.0, East: 18.0}
	center := bbox.Center()
	if center.Lat != 51.0 || center.Lon != 17.0 {
		t.Errorf("Center() = (%v, %v), want (51, 17)", center.Lat, center.Lon)
	}
}

func TestAreaMapKey(t *testing.T) {
	key := AreaMapKey(AreaTypeTown, "pobiedziska")
	if key != "town:pobiedziska" {
		t.Errorf("AreaMapKey = %q, want town:pobiedziska", key)
	}

	area := &Area{Slug: "pobiedziska", Type: AreaTypeTown}
	if area.MapKey() != "town:pobiedziska" {
		t.Errorf("Area.MapKey() = %q, want town:pobiedziska", area.MapKey())
	}
}

func TestAllAreaTypes(t *testing.T) {
	types := AllAreaTypes()
	if len(types) != 5 {
		t.Errorf("AllAreaTypes() returned %d types, want 5", len(types))
	}
}
