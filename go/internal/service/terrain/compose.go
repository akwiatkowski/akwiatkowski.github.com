package terrain

import (
	"fmt"
	"image"
	"image/color"
	"io"
	"math"
	"strconv"
	"strings"

	"odkrywajac/internal/model"
	"odkrywajac/internal/service/svg"
)

// Route styling. Widths are expressed relative to a 1000px-wide map and scaled
// to the actual output width, so the SVG and the raster PNGs draw the same
// visual thickness regardless of resolution.
const (
	routeBoldness    = 1.3 // multiplier for route thickness vs its config weight (output px)
	casingExtraPx    = 1.3 // white casing radius added around the colored core (output px)
	stampSpacingPx   = 0.6 // spacing between AA circle stamps along the route (output px)
	defaultRouteRGB  = "51,136,255"
	defaultRouteWide = 3 // fallback stroke weight when a route type has no config
)

// projector maps geographic coordinates into the output image's pixel space.
// It converts lat/lon to slippy-tile "world pixels" (the projection the photo
// maps use) and then linearly rescales the crop rectangle to the output size,
// so the route overlay lands exactly on the GDAL-rendered hillshade.
type projector struct {
	zoom         int
	minPX, minPY float64 // top-left of the crop rectangle, in world pixels
	cropW, cropH float64 // crop rectangle size, in world pixels
	width        float64 // output image width, in pixels
	height       float64 // output image height, in pixels
}

// project converts a lat/lon into an output-image pixel coordinate.
func (pr projector) project(lat, lon float64) (x, y float64) {
	px, py := svg.LatLonToPixel(lat, lon, pr.zoom)
	x = (px - pr.minPX) / pr.cropW * pr.width
	y = (py - pr.minPY) / pr.cropH * pr.height
	return x, y
}

// projectMercator converts an EPSG:3857 point (meters) into an output-image
// pixel coordinate. Used for contour lines, which GDAL emits in Web Mercator.
func (pr projector) projectMercator(mx, my float64) (x, y float64) {
	worldPx := 256.0 * math.Pow(2, float64(pr.zoom))
	px := (mx + mercatorR) / (2 * mercatorR) * worldPx
	py := (mercatorR - my) / (2 * mercatorR) * worldPx
	x = (px - pr.minPX) / pr.cropW * pr.width
	y = (py - pr.minPY) / pr.cropH * pr.height
	return x, y
}

// parseRouteColor turns a config color string ("51,136,255" or "rgb(0,70,240)")
// into an RGBA. Unparseable input falls back to the default route blue.
func parseRouteColor(s string) color.RGBA {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "rgb(")
	s = strings.TrimSuffix(s, ")")
	parts := strings.Split(s, ",")
	if len(parts) != 3 {
		return color.RGBA{51, 136, 255, 255}
	}
	vals := [3]uint8{}
	for i, p := range parts {
		n, err := strconv.Atoi(strings.TrimSpace(p))
		if err != nil || n < 0 || n > 255 {
			return color.RGBA{51, 136, 255, 255}
		}
		vals[i] = uint8(n)
	}
	return color.RGBA{vals[0], vals[1], vals[2], 255}
}

// routeStyle resolves the color and reference stroke weight for a route type.
func routeStyle(routeType string, routeColors map[string]model.RouteColor) (color.RGBA, int) {
	if rc, ok := routeColors[routeType]; ok {
		weight := rc.Weight
		if weight <= 0 {
			weight = defaultRouteWide
		}
		return parseRouteColor(rc.Color), weight
	}
	return parseRouteColor(defaultRouteRGB), defaultRouteWide
}

// rdpSimplify applies the Ramer–Douglas–Peucker algorithm to drop points within
// `epsilon` pixels of the line between their neighbors. Used to tame the wiggle
// of DEM-derived contour lines (the route itself is drawn unsimplified).
func rdpSimplify(points [][2]float64, epsilon float64) [][2]float64 {
	if len(points) < 3 || epsilon <= 0 {
		return points
	}
	first, last := points[0], points[len(points)-1]
	maxDist, idx := 0.0, 0
	for i := 1; i < len(points)-1; i++ {
		if d := perpDistance(points[i], first, last); d > maxDist {
			maxDist, idx = d, i
		}
	}
	if maxDist <= epsilon {
		return [][2]float64{first, last}
	}
	left := rdpSimplify(points[:idx+1], epsilon)
	right := rdpSimplify(points[idx:], epsilon)
	return append(left[:len(left)-1], right...)
}

// perpDistance returns the perpendicular distance from p to the line a→b.
func perpDistance(p, a, b [2]float64) float64 {
	dx, dy := b[0]-a[0], b[1]-a[1]
	length := math.Hypot(dx, dy)
	if length == 0 {
		return math.Hypot(p[0]-a[0], p[1]-a[1])
	}
	return math.Abs((p[0]-a[0])*dy-(p[1]-a[1])*dx) / length
}

// sampleLinear walks a polyline and emits points every ~spacing pixels along
// each straight segment (endpoints included). No smoothing — the route follows
// the raw GPS track exactly; this just densifies it so the AA circle-stamping
// leaves no gaps between far-apart track points.
func sampleLinear(points [][2]float64, spacing float64) [][2]float64 {
	if len(points) < 2 || spacing <= 0 {
		return points
	}
	out := [][2]float64{points[0]}
	for i := 1; i < len(points); i++ {
		a, b := points[i-1], points[i]
		dist := math.Hypot(b[0]-a[0], b[1]-a[1])
		steps := int(dist / spacing)
		if steps < 1 {
			steps = 1
		}
		for s := 1; s <= steps; s++ {
			t := float64(s) / float64(steps)
			out = append(out, [2]float64{a[0] + (b[0]-a[0])*t, a[1] + (b[1]-a[1])*t})
		}
	}
	return out
}

// mapContrast is a mild whole-map contrast lift applied after shading, pivoting
// around mid-grey (128): >1 spreads tones apart so features read more crisply.
const mapContrast = 1.1

// compositeShade multiplies the OSM base color by the hillshade brightness so
// the map surface keeps its identity while gaining terrain relief, then applies
// a small contrast lift. strength in [0,1] sets how dark the shadows go: the
// per-pixel factor is (1-strength) + strength*shade, so a fully-lit slope
// (shade=1) is unchanged and a fully-shadowed one darkens to (1-strength) of its
// color. base and shade must have the same dimensions.
func compositeShade(base, shade image.Image, strength float64) *image.RGBA {
	b := base.Bounds()
	w, h := b.Dx(), b.Dy()
	out := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			br, bg, bb, _ := base.At(b.Min.X+x, b.Min.Y+y).RGBA()
			sr, _, _, _ := shade.At(x, y).RGBA() // grayscale hillshade
			factor := (1 - strength) + strength*(float64(sr)/65535.0)
			i := out.PixOffset(x, y)
			out.Pix[i+0] = contrast8(float64(br>>8) * factor)
			out.Pix[i+1] = contrast8(float64(bg>>8) * factor)
			out.Pix[i+2] = contrast8(float64(bb>>8) * factor)
			out.Pix[i+3] = 255
		}
	}
	return out
}

// contrast8 applies mapContrast around mid-grey then clamps to a byte.
func contrast8(v float64) uint8 {
	return clamp8((v-128)*mapContrast + 128)
}

// drawRouteOnImage renders every route segment onto the raster with a white
// casing beneath a colored core, both anti-aliased, so routes read clearly over
// both dark and light terrain.
func drawRouteOnImage(img *image.RGBA, routes []model.Route, routeColors map[string]model.RouteColor, pr projector) {
	casing := color.RGBA{255, 255, 255, 255}

	for _, route := range routes {
		col, weight := routeStyle(route.Type, routeColors)
		coreRadius := float64(weight) * routeBoldness / 2.0
		if coreRadius < 1 {
			coreRadius = 1
		}
		casingRadius := coreRadius + casingExtraPx

		for _, seg := range route.Segments {
			if len(seg) < 2 {
				continue
			}
			pts := make([][2]float64, len(seg))
			for i, ll := range seg {
				x, y := pr.project(ll.Lat, ll.Lon)
				pts[i] = [2]float64{x, y}
			}
			pts = sampleLinear(pts, stampSpacingPx)
			stampLine(img, pts, casing, casingRadius)
			stampLine(img, pts, col, coreRadius)
		}
	}
}

// stampLine draws a thick, round-capped anti-aliased line by alpha-blending a
// soft-edged disc at every sampled point. Coverage is a 1px linear ramp at the
// disc edge — cheap and smooth for the modest radii used here.
func stampLine(img *image.RGBA, pts [][2]float64, col color.RGBA, radius float64) {
	bounds := img.Bounds()
	for _, p := range pts {
		cx, cy := p[0], p[1]
		x0 := int(math.Floor(cx - radius - 1))
		x1 := int(math.Ceil(cx + radius + 1))
		y0 := int(math.Floor(cy - radius - 1))
		y1 := int(math.Ceil(cy + radius + 1))
		for y := y0; y <= y1; y++ {
			if y < bounds.Min.Y || y >= bounds.Max.Y {
				continue
			}
			for x := x0; x <= x1; x++ {
				if x < bounds.Min.X || x >= bounds.Max.X {
					continue
				}
				dist := math.Hypot(float64(x)+0.5-cx, float64(y)+0.5-cy)
				cov := radius + 0.5 - dist // 1px linear AA ramp at the edge
				if cov <= 0 {
					continue
				}
				if cov > 1 {
					cov = 1
				}
				blendPixel(img, x, y, col, cov)
			}
		}
	}
}

// blendPixel alpha-blends src over the existing pixel with the given coverage.
func blendPixel(img *image.RGBA, x, y int, src color.RGBA, cov float64) {
	i := img.PixOffset(x, y)
	dr := float64(img.Pix[i+0])
	dg := float64(img.Pix[i+1])
	db := float64(img.Pix[i+2])
	img.Pix[i+0] = clamp8(float64(src.R)*cov + dr*(1-cov))
	img.Pix[i+1] = clamp8(float64(src.G)*cov + dg*(1-cov))
	img.Pix[i+2] = clamp8(float64(src.B)*cov + db*(1-cov))
	img.Pix[i+3] = 255
}

// buildSVG writes a self-describing SVG map: the shaded-relief raster as a
// full-bleed background image plus the route drawn as crisp vector polylines
// (white casing under colored core). reliefURL is the site-absolute path to the
// relief PNG. The densely-sampled spline is emitted as a polyline so the vector
// curve matches the raster route exactly.
func buildSVG(w io.Writer, routes []model.Route, routeColors map[string]model.RouteColor, pr projector, reliefURL string) {
	width := int(pr.width)
	height := int(pr.height)

	fmt.Fprintf(w, `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 %d %d" width="%d" height="%d">`,
		width, height, width, height)
	fmt.Fprintln(w)
	fmt.Fprintf(w, `<image xlink:href="%s" x="0" y="0" width="%d" height="%d" preserveAspectRatio="none"/>`,
		reliefURL, width, height)
	fmt.Fprintln(w)
	fmt.Fprintln(w, `<g fill="none" stroke-linecap="round" stroke-linejoin="round">`)

	for _, route := range routes {
		col, weight := routeStyle(route.Type, routeColors)
		coreW := float64(weight) * routeBoldness
		casingW := coreW + 2*casingExtraPx
		colStr := fmt.Sprintf("rgb(%d,%d,%d)", col.R, col.G, col.B)

		for _, seg := range route.Segments {
			if len(seg) < 2 {
				continue
			}
			// Raw GPS polyline — no smoothing.
			pts := make([][2]float64, len(seg))
			for i, ll := range seg {
				x, y := pr.project(ll.Lat, ll.Lon)
				pts[i] = [2]float64{x, y}
			}
			ptsStr := polylinePoints(pts)
			fmt.Fprintf(w, `<polyline points="%s" stroke="white" stroke-width="%.2f" opacity="0.9"/>`, ptsStr, casingW)
			fmt.Fprintln(w)
			fmt.Fprintf(w, `<polyline points="%s" stroke="%s" stroke-width="%.2f"/>`, ptsStr, colStr, coreW)
			fmt.Fprintln(w)
		}
	}

	fmt.Fprintln(w, `</g>`)
	fmt.Fprintln(w, `</svg>`)
}

// polylinePoints formats sampled points as an SVG polyline "points" attribute.
func polylinePoints(pts [][2]float64) string {
	var sb strings.Builder
	for i, p := range pts {
		if i > 0 {
			sb.WriteByte(' ')
		}
		fmt.Fprintf(&sb, "%.1f,%.1f", p[0], p[1])
	}
	return sb.String()
}
