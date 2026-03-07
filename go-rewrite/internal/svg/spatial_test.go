package svg

import (
	"testing"

	"odkrywajac/internal/model"
)

func makeGeoPhoto(lat, lon float64) *model.Photo {
	return &model.Photo{
		ImageFilename: "test.jpg",
		PostSlug:      "test",
		Exif: &model.ExifData{
			Lat: &lat,
			Lon: &lon,
		},
	}
}

func TestSpatialIndexQuery(t *testing.T) {
	photos := []*model.Photo{
		makeGeoPhoto(52.4, 16.9), // Poznan
		makeGeoPhoto(52.2, 21.0), // Warsaw
		makeGeoPhoto(50.0, 19.9), // Krakow
	}

	si := NewSpatialIndex(photos, DefaultResolution)

	// Query Poznan area
	result := si.Query(52.3, 52.5, 16.8, 17.0)
	if len(result) != 1 {
		t.Errorf("Poznan query: got %d photos, want 1", len(result))
	}

	// Query all of Poland
	result = si.Query(49.0, 55.0, 14.0, 25.0)
	if len(result) != 3 {
		t.Errorf("Poland query: got %d photos, want 3", len(result))
	}

	// Query empty area
	result = si.Query(40.0, 41.0, 10.0, 11.0)
	if len(result) != 0 {
		t.Errorf("empty query: got %d photos, want 0", len(result))
	}
}

func TestSpatialIndexSkipsNonGPS(t *testing.T) {
	photos := []*model.Photo{
		makeGeoPhoto(52.4, 16.9),
		{ImageFilename: "no-gps.jpg", PostSlug: "test"}, // no GPS
	}

	si := NewSpatialIndex(photos, DefaultResolution)
	result := si.Query(49.0, 55.0, 14.0, 25.0)
	if len(result) != 1 {
		t.Errorf("got %d, want 1 (should skip non-GPS)", len(result))
	}
}
