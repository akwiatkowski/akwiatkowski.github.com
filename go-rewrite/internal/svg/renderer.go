package svg

import (
	"crypto/sha256"
	"fmt"
	"io"
	"math"
	"sort"
	"strings"
	"sync"
	"time"

	"odkrywajac/internal/model"
)

// RouteData holds a route with its type for color selection.
type RouteData struct {
	Type     string
	Segments [][]model.LatLon
}

// SvgMapParams holds all inputs for generating one SVG photo map.
// Used both for rendering and for computing the input hash for caching.
type SvgMapParams struct {
	URL string // output URL, e.g. "/mapa_zdjec/overall.svg"

	// Config
	Zoom      int
	PhotoSize int
	Width     int // output SVG width (default 1000)

	// Drawing options
	DrawPhotos bool
	DrawRoutes bool
	DrawDots   bool

	// Fixed bounds (optional — e.g. voivodeship bbox)
	UseFixedBounds bool
	FixedBounds    [4]float64 // [latMin, latMax, lonMin, lonMax]

	// Data (references — SiteData is frozen)
	Photos      []*model.Photo
	Routes      []RouteData
	PostBySlug  map[string]*model.Post
	RouteColors map[string]model.RouteColor
}

// InputHash computes a deterministic hash of all inputs.
func (p *SvgMapParams) InputHash() string {
	h := sha256.New()

	// Hash config
	fmt.Fprintf(h, "z%d:ps%d:w%d:dp%v:dr%v:dd%v",
		p.Zoom, p.PhotoSize, p.Width,
		p.DrawPhotos, p.DrawRoutes, p.DrawDots)

	// Hash fixed bounds
	if p.UseFixedBounds {
		fmt.Fprintf(h, ":fb%.6f,%.6f,%.6f,%.6f",
			p.FixedBounds[0], p.FixedBounds[1], p.FixedBounds[2], p.FixedBounds[3])
	}

	// Hash photo GPS coords + slugs (sorted by slug+filename for determinism)
	sorted := make([]*model.Photo, len(p.Photos))
	copy(sorted, p.Photos)
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].PostSlug != sorted[j].PostSlug {
			return sorted[i].PostSlug < sorted[j].PostSlug
		}
		return sorted[i].ImageFilename < sorted[j].ImageFilename
	})
	for _, photo := range sorted {
		if photo.HasGPS() {
			fmt.Fprintf(h, ":%s/%s:%.6f,%.6f", photo.PostSlug, photo.ImageFilename, *photo.Exif.Lat, *photo.Exif.Lon)
		}
	}

	// Hash route segments (type + point count per segment)
	for _, route := range p.Routes {
		fmt.Fprintf(h, ":r:%s", route.Type)
		for _, seg := range route.Segments {
			fmt.Fprintf(h, ":%d", len(seg))
		}
	}

	return fmt.Sprintf("%x", h.Sum(nil))
}

// SvgMapView implements Renderable and InputHasher for SVG maps.
type SvgMapView struct {
	Params    SvgMapParams
	hashOnce  sync.Once
	hashValue string
}

// NewSvgMapView creates a view wrapper around SvgMapParams.
func NewSvgMapView(params SvgMapParams) *SvgMapView {
	return &SvgMapView{Params: params}
}

func (v *SvgMapView) URL() string        { return v.Params.URL }
func (v *SvgMapView) AddToSitemap() bool { return false }

func (v *SvgMapView) Render(w io.Writer) error {
	return RenderSVG(w, v.Params)
}

func (v *SvgMapView) InputHash() string {
	v.hashOnce.Do(func() { v.hashValue = v.Params.InputHash() })
	return v.hashValue
}

// RenderSVG renders a complete SVG photo map from params.
func RenderSVG(w io.Writer, p SvgMapParams) error {
	if p.Width == 0 {
		p.Width = 1000
	}

	// Collect all coordinate points for bounds computation
	var allPoints [][2]float64
	for _, photo := range p.Photos {
		if photo.HasGPS() {
			allPoints = append(allPoints, [2]float64{*photo.Exif.Lat, *photo.Exif.Lon})
		}
	}
	for _, route := range p.Routes {
		for _, seg := range route.Segments {
			for _, ll := range seg {
				allPoints = append(allPoints, [2]float64{ll.Lat, ll.Lon})
			}
		}
	}

	if len(allPoints) == 0 {
		// Empty map
		fmt.Fprintf(w, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d"></svg>`, p.Width, p.Width)
		return nil
	}

	// Compute or use fixed bounds
	var bounds MapBounds
	if p.UseFixedBounds {
		pxMinX, pxMinY := LatLonToPixel(p.FixedBounds[1], p.FixedBounds[2], p.Zoom) // NW corner (latMax, lonMin)
		pxMaxX, pxMaxY := LatLonToPixel(p.FixedBounds[0], p.FixedBounds[3], p.Zoom) // SE corner (latMin, lonMax)
		bounds = MapBounds{MinPX: pxMinX, MaxPX: pxMaxX, MinPY: pxMinY, MaxPY: pxMaxY}
	} else {
		bounds = ComputeMapBounds(allPoints, p.Zoom, 80)
	}

	cropW := bounds.Width()
	cropH := bounds.Height()
	if cropW < 300 {
		cropW = 300
	}
	if cropH < 300 {
		cropH = 300
	}

	aspectRatio := cropW / cropH
	svgHeight := int(float64(p.Width) / aspectRatio)

	// SVG header
	fmt.Fprintf(w, `<svg preserveAspectRatio="xMinYMin meet" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">`, p.Width, svgHeight)
	fmt.Fprintln(w)

	// Defs
	writeSVGDefs(w)

	// Inner SVG with crop viewport
	fmt.Fprintf(w, `<svg width="%d" height="%d" viewBox="%.0f %.0f %.0f %.0f" class="photo-map-tiles">`,
		p.Width, svgHeight, bounds.MinPX, bounds.MinPY, cropW, cropH)
	fmt.Fprintln(w)

	// Tiles layer (placeholder references)
	writeTilesLayer(w, bounds, p.Zoom)

	// Photo grid layer
	if p.DrawPhotos && p.PhotoSize > 0 {
		writePhotoGridLayer(w, p, bounds)
	}

	// Dots layer
	if p.DrawDots {
		writeDotsLayer(w, p, bounds)
	}

	// Routes layer
	if p.DrawRoutes {
		writeRoutesLayer(w, p, bounds)
	}

	fmt.Fprintln(w, `</svg>`)

	// License
	fmt.Fprintf(w, `<a href="https://mapa.ump.waw.pl/ump-www/" target="_blank">`)
	fmt.Fprintf(w, `<text x="%d" y="%d" class="licence-text">mapa z UMP-pcPL</text>`, p.Width-8, svgHeight-8)
	fmt.Fprintln(w, `</a>`)

	fmt.Fprintln(w, `</svg>`)
	return nil
}

func writeSVGDefs(w io.Writer) {
	fmt.Fprintln(w, `<defs>`)
	fmt.Fprintln(w, `<filter id="photo-shadow" x="-5%" y="-5%" width="115%" height="115%">`)
	fmt.Fprintln(w, `<feDropShadow dx="1" dy="1" stdDeviation="2" flood-color="rgba(0,0,0,0.25)"/>`)
	fmt.Fprintln(w, `</filter>`)
	fmt.Fprintln(w, `<filter id="route-glow" x="-15%" y="-15%" width="130%" height="130%">`)
	fmt.Fprintln(w, `<feGaussianBlur in="SourceGraphic" stdDeviation="3"/>`)
	fmt.Fprintln(w, `</filter>`)
	fmt.Fprintln(w, `</defs>`)
	fmt.Fprintln(w, `<style>`)
	fmt.Fprintln(w, `.photo-map-photo { filter: url(#photo-shadow); }`)
	fmt.Fprintln(w, `.photo-map-route { stroke-linecap: round; stroke-linejoin: round; }`)
	fmt.Fprintln(w, `.photo-dot { stroke: rgba(0,0,0,0.5); stroke-width: 0.5; }`)
	fmt.Fprintln(w, `.photo-border { fill: none; stroke: rgba(255,255,255,0.7); stroke-width: 1; }`)
	fmt.Fprintln(w, `.licence-text { font-family: sans-serif; font-size: 11px; fill: rgba(0,0,0,0.45); text-anchor: end; }`)
	fmt.Fprintln(w, `</style>`)
}

func writeTilesLayer(w io.Writer, bounds MapBounds, zoom int) {
	fmt.Fprintln(w, `<g id="photo-map-tiles">`)
	tileMinX := int(bounds.MinPX / TileWidth)
	tileMaxX := int(bounds.MaxPX / TileWidth)
	tileMinY := int(bounds.MinPY / TileWidth)
	tileMaxY := int(bounds.MaxPY / TileWidth)

	for tx := tileMinX; tx <= tileMaxX; tx++ {
		for ty := tileMinY; ty <= tileMaxY; ty++ {
			x := tx * TileWidth
			y := ty * TileWidth
			fmt.Fprintf(w, `<image href="/tiles/ump/%d/%d/%d.png" x="%d" y="%d" width="%d" height="%d" class="photo-map-tile"/>`,
				zoom, tx, ty, x, y, TileWidth, TileWidth)
			fmt.Fprintln(w)
		}
	}
	fmt.Fprintln(w, `</g>`)
}

func writePhotoGridLayer(w io.Writer, p SvgMapParams, bounds MapBounds) {
	// Build spatial index for efficient grid queries
	si := NewSpatialIndex(p.Photos, DefaultResolution)
	ps := float64(p.PhotoSize)

	fmt.Fprintln(w, `<g id="photo-map-photos">`)

	// Iterate grid cells
	for x := bounds.MinPX; x <= bounds.MaxPX; x += ps {
		for y := bounds.MinPY; y <= bounds.MaxPY; y += ps {
			// Convert pixel corners back to lat/lon
			lat1, lon1 := PixelToLatLon(x, y, p.Zoom)
			lat2, lon2 := PixelToLatLon(x+ps, y+ps, p.Zoom)

			// Query spatial index (Y-axis inverted: lat2 < lat1)
			photos := si.Query(lat2, lat1, lon1, lon2)
			if len(photos) == 0 {
				continue
			}

			// Select best photo
			photo := selectBestPhoto(photos)
			if photo == nil {
				continue
			}

			// Get post for URL
			post := p.PostBySlug[photo.PostSlug]
			if post == nil {
				continue
			}

			// Render grid cell
			imgURL := fmt.Sprintf("/images/processed/%d/%02d/%s_%s_grid.jpg",
				post.Date.Year(), post.Date.Month(), post.Slug, photo.ImageFilename)
			postURL := model.BuildPostURL(post.Date, post.Slug)

			fmt.Fprintf(w, `<svg x="%.0f" y="%.0f" width="%d" height="%d" class="photo-map-photo">`,
				x, y, p.PhotoSize, p.PhotoSize)
			fmt.Fprintf(w, `<a href="%s" target="_blank">`, postURL)
			fmt.Fprintf(w, `<image href="%s" preserveAspectRatio="xMidYMid slice" width="%d" height="%d"/>`,
				imgURL, p.PhotoSize, p.PhotoSize)
			fmt.Fprintf(w, `</a>`)
			fmt.Fprintf(w, `<rect width="%d" height="%d" class="photo-border"/>`,
				p.PhotoSize, p.PhotoSize)
			fmt.Fprintln(w, `</svg>`)
		}
	}

	fmt.Fprintln(w, `</g>`)
}

func selectBestPhoto(photos []*model.Photo) *model.Photo {
	if len(photos) == 0 {
		return nil
	}

	// Priority: IsTimeline > any, then sort by time (latest wins)
	var candidates []*model.Photo

	// Priority 1: timeline photos
	for _, p := range photos {
		if p.IsTimeline {
			candidates = append(candidates, p)
		}
	}

	if len(candidates) == 0 {
		candidates = photos
	}

	// Sort by time ascending, return latest
	sort.Slice(candidates, func(i, j int) bool {
		ti := photoTimeSafe(candidates[i])
		tj := photoTimeSafe(candidates[j])
		return ti.Before(tj)
	})

	return candidates[len(candidates)-1]
}

func photoTimeSafe(p *model.Photo) time.Time {
	if p.Exif != nil && p.Exif.Time != nil {
		return *p.Exif.Time
	}
	return time.Time{}
}

func writeDotsLayer(w io.Writer, p SvgMapParams, bounds MapBounds) {
	fmt.Fprintln(w, `<g id="photo-map-dots">`)
	for _, photo := range p.Photos {
		if !photo.HasGPS() {
			continue
		}
		px, py := LatLonToPixel(*photo.Exif.Lat, *photo.Exif.Lon, p.Zoom)
		if px < bounds.MinPX || px > bounds.MaxPX || py < bounds.MinPY || py > bounds.MaxPY {
			continue
		}
		color := dayOfYearColor(photo)
		fmt.Fprintf(w, `<circle cx="%.0f" cy="%.0f" r="3" fill="%s" class="photo-dot"/>`, px, py, color)
		fmt.Fprintln(w)
	}
	fmt.Fprintln(w, `</g>`)
}

func dayOfYearColor(photo *model.Photo) string {
	doy := 180 // default mid-year
	if photo.Exif != nil && photo.Exif.Time != nil {
		doy = photo.Exif.Time.YearDay()
	}

	phase := float64(doy) / 365.0 * 2.0 * math.Pi
	blue := 255.0 * (math.Cos(phase) + 1.0) / 2.0
	green := 255.0 * (math.Sin(phase) + 1.0) / 2.0
	red := 0.0
	if doy >= 150 && doy < 350 {
		redPhase := float64(doy-150) / 200.0 * math.Pi
		red = 255.0 * math.Sin(redPhase)
	}

	return fmt.Sprintf("rgb(%d,%d,%d)", clampInt(int(red)), clampInt(int(green)), clampInt(int(blue)))
}

func clampInt(v int) int {
	if v < 0 {
		return 0
	}
	if v > 255 {
		return 255
	}
	return v
}

func writeRoutesLayer(w io.Writer, p SvgMapParams, _ MapBounds) {
	fmt.Fprintln(w, `<g id="photo-map-routes">`)
	for _, route := range p.Routes {
		color := "51,136,255" // default blue
		weight := 2
		if rc, ok := p.RouteColors[route.Type]; ok {
			color = rc.Color
			weight = rc.Weight
		}

		for _, seg := range route.Segments {
			if len(seg) < 2 {
				continue
			}
			points := make([][2]int, len(seg))
			for i, ll := range seg {
				px, py := LatLonToPixel(ll.Lat, ll.Lon, p.Zoom)
				points[i] = [2]int{int(px), int(py)}
			}

			pathD := smoothPath(points)
			if pathD == "" {
				continue
			}

			// Glow layer
			fmt.Fprintf(w, `<path fill="none" stroke="rgb(%s)" stroke-width="%d" opacity="0.25" filter="url(#route-glow)" d="%s"/>`,
				color, weight*3, pathD)
			fmt.Fprintln(w)
			// Main layer
			fmt.Fprintf(w, `<path class="photo-map-route" fill="none" stroke="rgb(%s)" stroke-width="%d" d="%s"/>`,
				color, weight, pathD)
			fmt.Fprintln(w)
		}
	}
	fmt.Fprintln(w, `</g>`)
}

// smoothPath generates a Catmull-Rom spline SVG path from integer points.
func smoothPath(points [][2]int) string {
	if len(points) == 0 {
		return ""
	}
	if len(points) == 1 {
		return fmt.Sprintf("M %d,%d", points[0][0], points[0][1])
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("M %d,%d", points[0][0], points[0][1]))

	if len(points) == 2 {
		sb.WriteString(fmt.Sprintf(" L %d,%d", points[1][0], points[1][1]))
		return sb.String()
	}

	for i := 0; i < len(points)-1; i++ {
		var p0, p1, p2, p3 [2]int
		if i > 0 {
			p0 = points[i-1]
		} else {
			p0 = points[i]
		}
		p1 = points[i]
		p2 = points[i+1]
		if i+2 < len(points) {
			p3 = points[i+2]
		} else {
			p3 = points[i+1]
		}

		cp1x := float64(p1[0]) + float64(p2[0]-p0[0])/6.0
		cp1y := float64(p1[1]) + float64(p2[1]-p0[1])/6.0
		cp2x := float64(p2[0]) - float64(p3[0]-p1[0])/6.0
		cp2y := float64(p2[1]) - float64(p3[1]-p1[1])/6.0

		sb.WriteString(fmt.Sprintf(" C %d,%d %d,%d %d,%d",
			int(math.Round(cp1x)), int(math.Round(cp1y)),
			int(math.Round(cp2x)), int(math.Round(cp2y)),
			p2[0], p2[1]))
	}

	return sb.String()
}
