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
	referenceWidth   = 1000.0 // width the reference weights are calibrated for
	routeBoldness    = 1.6    // multiplier making routes a touch bolder than on photo maps
	casingExtraPx    = 1.6    // white casing radius added around the colored core (at ref width)
	stampSpacingPx   = 0.6    // spacing between AA circle stamps along the route (ref width)
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

// scale returns the reference-width-relative scale factor for this output size.
func (pr projector) scale() float64 { return pr.width / referenceWidth }

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

// sampleCatmullRom expands a polyline of control points into a dense, smooth
// polyline using a uniform Catmull-Rom spline (the same curve the SVG photo maps
// draw as Béziers). Sampling density follows the chord length so stamps stay
// evenly spaced. Points are in output-image pixel space.
func sampleCatmullRom(points [][2]float64, spacing float64) [][2]float64 {
	if len(points) < 3 {
		return points // nothing to smooth
	}
	var out [][2]float64
	out = append(out, points[0])
	for i := 0; i < len(points)-1; i++ {
		p0 := points[max0(i-1)]
		p1 := points[i]
		p2 := points[i+1]
		p3 := points[min0(i+2, len(points)-1)]

		chord := math.Hypot(p2[0]-p1[0], p2[1]-p1[1])
		steps := int(chord / spacing)
		if steps < 1 {
			steps = 1
		}
		for s := 1; s <= steps; s++ {
			t := float64(s) / float64(steps)
			out = append(out, catmullRomPoint(p0, p1, p2, p3, t))
		}
	}
	return out
}

// catmullRomPoint evaluates the uniform Catmull-Rom basis at parameter t in the
// segment p1→p2 (p0 and p3 are the neighboring control points that set the
// tangents).
func catmullRomPoint(p0, p1, p2, p3 [2]float64, t float64) [2]float64 {
	t2 := t * t
	t3 := t2 * t
	var q [2]float64
	for a := 0; a < 2; a++ {
		q[a] = 0.5 * ((2 * p1[a]) +
			(-p0[a]+p2[a])*t +
			(2*p0[a]-5*p1[a]+4*p2[a]-p3[a])*t2 +
			(-p0[a]+3*p1[a]-3*p2[a]+p3[a])*t3)
	}
	return q
}

func max0(v int) int {
	if v < 0 {
		return 0
	}
	return v
}
func min0(v, hi int) int {
	if v > hi {
		return hi
	}
	return v
}

// compositeShade multiplies the OSM base color by the hillshade brightness so
// the map surface keeps its identity while gaining terrain relief. strength in
// [0,1] sets how dark the shadows go: the per-pixel factor is
// (1-strength) + strength*shade, so a fully-lit slope (shade=1) is unchanged
// and a fully-shadowed one (shade=0) darkens to (1-strength) of its color.
// base and shade must have the same dimensions.
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
			out.Pix[i+0] = clamp8(float64(br>>8) * factor)
			out.Pix[i+1] = clamp8(float64(bg>>8) * factor)
			out.Pix[i+2] = clamp8(float64(bb>>8) * factor)
			out.Pix[i+3] = 255
		}
	}
	return out
}

// drawRouteOnImage renders every route segment onto the raster with a white
// casing beneath a colored core, both anti-aliased, so routes read clearly over
// both dark and light terrain.
func drawRouteOnImage(img *image.RGBA, routes []model.Route, routeColors map[string]model.RouteColor, pr projector) {
	scale := pr.scale()
	spacing := stampSpacingPx * scale
	casing := color.RGBA{255, 255, 255, 255}

	for _, route := range routes {
		col, weight := routeStyle(route.Type, routeColors)
		coreRadius := float64(weight) * routeBoldness * scale / 2.0
		if coreRadius < 1 {
			coreRadius = 1
		}
		casingRadius := coreRadius + casingExtraPx*scale

		for _, seg := range route.Segments {
			if len(seg) < 2 {
				continue
			}
			ctrl := make([][2]float64, len(seg))
			for i, ll := range seg {
				x, y := pr.project(ll.Lat, ll.Lon)
				ctrl[i] = [2]float64{x, y}
			}
			pts := sampleCatmullRom(ctrl, spacing)
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
	scale := pr.scale()

	fmt.Fprintf(w, `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 %d %d" width="%d" height="%d">`,
		width, height, width, height)
	fmt.Fprintln(w)
	fmt.Fprintf(w, `<image xlink:href="%s" x="0" y="0" width="%d" height="%d" preserveAspectRatio="none"/>`,
		reliefURL, width, height)
	fmt.Fprintln(w)
	fmt.Fprintln(w, `<g fill="none" stroke-linecap="round" stroke-linejoin="round">`)

	for _, route := range routes {
		col, weight := routeStyle(route.Type, routeColors)
		coreW := float64(weight) * routeBoldness * scale
		casingW := coreW + 2*casingExtraPx*scale
		colStr := fmt.Sprintf("rgb(%d,%d,%d)", col.R, col.G, col.B)

		for _, seg := range route.Segments {
			if len(seg) < 2 {
				continue
			}
			ctrl := make([][2]float64, len(seg))
			for i, ll := range seg {
				x, y := pr.project(ll.Lat, ll.Lon)
				ctrl[i] = [2]float64{x, y}
			}
			pts := sampleCatmullRom(ctrl, stampSpacingPx*scale*8) // coarser is fine for vectors
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
