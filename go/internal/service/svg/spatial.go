package svg

import "odkrywajac/internal/model"

const DefaultResolution = 0.05 // ~5.5km × 3.5km at Poland's latitude

type bucketKey struct {
	latI, lonI int
}

// SpatialIndex provides O(1) grid queries for geotagged photos.
type SpatialIndex struct {
	buckets    map[bucketKey][]*model.Photo
	resolution float64
}

// NewSpatialIndex creates a spatial index with the given resolution in degrees.
func NewSpatialIndex(photos []*model.Photo, resolution float64) *SpatialIndex {
	si := &SpatialIndex{
		buckets:    make(map[bucketKey][]*model.Photo),
		resolution: resolution,
	}
	for _, p := range photos {
		if !p.HasGPS() {
			continue
		}
		key := si.bucketFor(*p.Exif.Lat, *p.Exif.Lon)
		si.buckets[key] = append(si.buckets[key], p)
	}
	return si
}

func (si *SpatialIndex) bucketFor(lat, lon float64) bucketKey {
	return bucketKey{
		latI: int(lat / si.resolution),
		lonI: int(lon / si.resolution),
	}
}

// Query returns all photos within the given lat/lon rectangle.
func (si *SpatialIndex) Query(latMin, latMax, lonMin, lonMax float64) []*model.Photo {
	bLatMin := int(latMin / si.resolution)
	bLatMax := int(latMax / si.resolution)
	bLonMin := int(lonMin / si.resolution)
	bLonMax := int(lonMax / si.resolution)

	// Handle negative coordinates
	if latMin < 0 {
		bLatMin--
	}
	if lonMin < 0 {
		bLonMin--
	}

	var results []*model.Photo
	for latI := bLatMin; latI <= bLatMax; latI++ {
		for lonI := bLonMin; lonI <= bLonMax; lonI++ {
			for _, photo := range si.buckets[bucketKey{latI, lonI}] {
				lat := *photo.Exif.Lat
				lon := *photo.Exif.Lon
				if lat >= latMin && lat < latMax && lon >= lonMin && lon < lonMax {
					results = append(results, photo)
				}
			}
		}
	}
	return results
}
