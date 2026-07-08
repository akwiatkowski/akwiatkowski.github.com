// Package svg provides Mercator projection, spatial indexing, and SVG map rendering.
package svg

import "math"

const TileWidth = 256

// BoundsPadding is the pixel margin added around map content (per side) at the
// render zoom, so routes and photos don't sit flush against the map edge.
const BoundsPadding = 80.0

// FitZoom picks the integer tile zoom at which a lat/lon bounding box best fills
// targetPx pixels. It fits the LARGER of the two axes, so the whole box stays
// visible and the raster tiles render close to 1:1 — crisp — instead of being
// heavily up- or down-scaled. The map's on-screen size is fixed by the output
// width and the box aspect ratio; zoom only sets tile detail, so the goal is
// simply to match tile resolution to display resolution.
//
// The result is rounded to nearest (a slight downscale reads sharper than an
// upscale) and clamped to [minZoom, maxZoom].
func FitZoom(latMin, latMax, lonMin, lonMax, targetPx float64, minZoom, maxZoom int) int {
	// Pixel spans at zoom 0 (Mercator). NW = (latMax, lonMin), SE = (latMin, lonMax).
	xNW, yNW := LatLonToPixel(latMax, lonMin, 0)
	xSE, ySE := LatLonToPixel(latMin, lonMax, 0)
	wpx0 := math.Abs(xSE - xNW)
	hpx0 := math.Abs(ySE - yNW)

	// Fit the larger axis (bigger span needs the smaller zoom to fit).
	span := math.Max(wpx0, hpx0)
	if span <= 0 {
		// Degenerate box (single point / zero span): show the most detail we can.
		return maxZoom
	}

	zoom := int(math.Round(math.Log2(targetPx / span)))
	if zoom < minZoom {
		zoom = minZoom
	}
	if zoom > maxZoom {
		zoom = maxZoom
	}
	return zoom
}

// TileCoords converts lat/lon to tile coordinates at a given zoom level.
func TileCoords(latDeg, lonDeg float64, zoom int) (x, y float64) {
	latRad := latDeg / 180.0 * math.Pi
	n := math.Pow(2.0, float64(zoom))
	x = (lonDeg + 180.0) / 360.0 * n
	y = (1.0 - math.Log(math.Tan(latRad)+1.0/math.Cos(latRad))/math.Pi) / 2.0 * n
	return
}

// GeoCoords converts tile coordinates back to lat/lon.
func GeoCoords(tileX, tileY float64, zoom int) (lat, lon float64) {
	n := math.Pow(2.0, float64(zoom))
	lon = tileX/n*360.0 - 180.0
	latRad := math.Atan(math.Sinh(math.Pi * (1.0 - 2.0*tileY/n)))
	lat = 180.0 * latRad / math.Pi
	return
}

// LatLonToPixel converts lat/lon to pixel position within a map at given zoom.
func LatLonToPixel(latDeg, lonDeg float64, zoom int) (px, py float64) {
	tx, ty := TileCoords(latDeg, lonDeg, zoom)
	px = tx * TileWidth
	py = ty * TileWidth
	return
}

// PixelToLatLon converts pixel coordinates back to lat/lon.
func PixelToLatLon(px, py float64, zoom int) (lat, lon float64) {
	tx := px / TileWidth
	ty := py / TileWidth
	return GeoCoords(tx, ty, zoom)
}

// MapBounds returns the pixel bounding box for a set of coordinates at a zoom level.
type MapBounds struct {
	MinPX, MaxPX float64
	MinPY, MaxPY float64
}

// ComputeMapBounds calculates pixel bounds for a set of lat/lon points.
func ComputeMapBounds(points [][2]float64, zoom int, padding float64) MapBounds {
	if len(points) == 0 {
		return MapBounds{}
	}
	mb := MapBounds{
		MinPX: math.Inf(1), MaxPX: math.Inf(-1),
		MinPY: math.Inf(1), MaxPY: math.Inf(-1),
	}
	for _, p := range points {
		px, py := LatLonToPixel(p[0], p[1], zoom)
		if px < mb.MinPX {
			mb.MinPX = px
		}
		if px > mb.MaxPX {
			mb.MaxPX = px
		}
		if py < mb.MinPY {
			mb.MinPY = py
		}
		if py > mb.MaxPY {
			mb.MaxPY = py
		}
	}
	mb.MinPX -= padding
	mb.MinPY -= padding
	mb.MaxPX += padding
	mb.MaxPY += padding
	return mb
}

func (mb MapBounds) Width() float64  { return mb.MaxPX - mb.MinPX }
func (mb MapBounds) Height() float64 { return mb.MaxPY - mb.MinPY }
