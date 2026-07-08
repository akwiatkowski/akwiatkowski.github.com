package terrain

import (
	"fmt"
	"image"
	"image/color"
	"io"
	"math"
	"strings"

	"odkrywajac/internal/model"
)

// Gradient color ramp (by absolute slope %). Tuned for lowland Poland where
// most of a ride is gentle: flat is green, and the rare real climbs go orange →
// red so they stand out. Up and down of equal steepness share a color (the map
// shows *where it's steep*, the elevation profile shows direction).
func gradientColor(pct float64) color.RGBA {
	switch a := math.Abs(pct); {
	case a < 2:
		return color.RGBA{0x3F, 0xA3, 0x4D, 255} // green — flat
	case a < 4:
		return color.RGBA{0x9A, 0xC4, 0x3A, 255} // lime — easy
	case a < 6:
		return color.RGBA{0xE0, 0xB8, 0x2E, 255} // amber — moderate
	case a < 9:
		return color.RGBA{0xE3, 0x83, 0x2E, 255} // orange — hard
	default:
		return color.RGBA{0xD2, 0x45, 0x2F, 255} // red — very steep
	}
}

// gradientSmoothM is the distance window (meters) over which slope is measured.
// The 10m DEM plus dense GPS points make point-to-point slope very noisy;
// measuring elevation change across ~60 m of route smooths it to something that
// reads as real terrain rather than sensor jitter.
const gradientSmoothM = 60.0

// segGradient is one route segment (a point pair) with its slope percentage.
type segGradient struct {
	a, b [2]float64 // endpoint lat/lon: {lat, lon}
	pct  float64    // signed slope %
}

// routeGradients computes per-segment slope for every route of a post, sampling
// elevation from the DEM and smoothing over gradientSmoothM. Returns nil if no
// elevation is available (caller then skips the gradient variant).
func routeGradients(post *model.Post, sampler *elevationSampler) [][]segGradient {
	var out [][]segGradient
	haveData := false
	for _, route := range post.Routes {
		for _, seg := range route.Segments {
			if len(seg) < 2 {
				continue
			}
			// Cumulative distance (m) and elevation per point (gap-filled).
			n := len(seg)
			dist := make([]float64, n)
			elev := make([]float64, n)
			ok := make([]bool, n)
			for i, ll := range seg {
				if i > 0 {
					dist[i] = dist[i-1] + haversineKm(seg[i-1].Lat, seg[i-1].Lon, ll.Lat, ll.Lon)*1000
				}
				elev[i], ok[i] = sampler.at(ll.Lat, ll.Lon)
			}
			if !fillGaps(elev, ok, dist) {
				continue
			}
			haveData = true

			grads := make([]segGradient, 0, n-1)
			for i := 0; i < n-1; i++ {
				// Slope across a window centered on the segment: find points
				// ~gradientSmoothM behind i and ahead of i+1.
				lo, hi := i, i+1
				for lo > 0 && dist[i]-dist[lo] < gradientSmoothM/2 {
					lo--
				}
				for hi < n-1 && dist[hi]-dist[i+1] < gradientSmoothM/2 {
					hi++
				}
				run := dist[hi] - dist[lo]
				pct := 0.0
				if run > 1 {
					pct = (elev[hi] - elev[lo]) / run * 100
				}
				grads = append(grads, segGradient{
					a:   [2]float64{seg[i].Lat, seg[i].Lon},
					b:   [2]float64{seg[i+1].Lat, seg[i+1].Lon},
					pct: pct,
				})
			}
			out = append(out, grads)
		}
	}
	if !haveData {
		return nil
	}
	return out
}

// drawGradientRouteOnImage draws the route onto the raster with each segment
// colored by its slope, over a white casing so it reads on any terrain.
func drawGradientRouteOnImage(img *image.RGBA, grads [][]segGradient, pr projector) {
	casing := color.RGBA{255, 255, 255, 255}
	coreRadius := float64(defaultRouteWide) * routeBoldness / 2.0
	if coreRadius < 1 {
		coreRadius = 1
	}
	casingRadius := coreRadius + casingExtraPx

	// Casing pass first (whole route), so segment joins don't show white gaps.
	for _, segs := range grads {
		for _, g := range segs {
			pts := segmentPoints(g, pr)
			stampLine(img, pts, casing, casingRadius)
		}
	}
	// Colored core pass.
	for _, segs := range grads {
		for _, g := range segs {
			pts := segmentPoints(g, pr)
			stampLine(img, pts, gradientColor(g.pct), coreRadius)
		}
	}
}

// segmentPoints projects a segment's endpoints and densifies them for stamping.
func segmentPoints(g segGradient, pr projector) [][2]float64 {
	ax, ay := pr.project(g.a[0], g.a[1])
	bx, by := pr.project(g.b[0], g.b[1])
	return sampleLinear([][2]float64{{ax, ay}, {bx, by}}, stampSpacingPx)
}

// gradientLegend labels the slope color ramp shown on the gradient map.
var gradientLegend = []struct {
	label string
	pct   float64
}{
	{"0–2%", 1}, {"2–4%", 3}, {"4–6%", 5}, {"6–9%", 7}, {"9%+", 10},
}

// buildGradientSVG writes the gradient map SVG: the shared relief background, a
// route whose segments are colored by slope (white casing beneath), and a small
// legend of the color ramp.
func buildGradientSVG(w io.Writer, grads [][]segGradient, pr projector, reliefURL string) {
	width := int(pr.width)
	height := int(pr.height)
	coreW := float64(defaultRouteWide) * routeBoldness
	casingW := coreW + 2*casingExtraPx

	fmt.Fprintf(w, `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 %d %d" width="%d" height="%d">`,
		width, height, width, height)
	fmt.Fprintln(w)
	fmt.Fprintf(w, `<image xlink:href="%s" x="0" y="0" width="%d" height="%d" preserveAspectRatio="none"/>`,
		reliefURL, width, height)
	fmt.Fprintln(w)
	fmt.Fprintln(w, `<g fill="none" stroke-linecap="round" stroke-linejoin="round">`)

	// White casing: one polyline per route so joins stay clean.
	for _, segs := range grads {
		if len(segs) == 0 {
			continue
		}
		var sb strings.Builder
		x0, y0 := pr.project(segs[0].a[0], segs[0].a[1])
		fmt.Fprintf(&sb, "M%.1f,%.1f ", x0, y0)
		for _, g := range segs {
			x, y := pr.project(g.b[0], g.b[1])
			fmt.Fprintf(&sb, "L%.1f,%.1f ", x, y)
		}
		fmt.Fprintf(w, `<path d="%s" stroke="white" stroke-width="%.2f" opacity="0.9"/>`, strings.TrimSpace(sb.String()), casingW)
		fmt.Fprintln(w)
	}
	// Colored cores: one line per segment.
	for _, segs := range grads {
		for _, g := range segs {
			x1, y1 := pr.project(g.a[0], g.a[1])
			x2, y2 := pr.project(g.b[0], g.b[1])
			c := gradientColor(g.pct)
			fmt.Fprintf(w, `<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="rgb(%d,%d,%d)" stroke-width="%.2f"/>`,
				x1, y1, x2, y2, c.R, c.G, c.B, coreW)
			fmt.Fprintln(w)
		}
	}
	fmt.Fprintln(w, `</g>`)

	// Legend: swatches bottom-left.
	lx, ly := 12, height-14
	fmt.Fprintf(w, `<g font-family="sans-serif" font-size="11">`)
	for i, item := range gradientLegend {
		c := gradientColor(item.pct)
		sx := lx + i*70
		fmt.Fprintf(w, `<rect x="%d" y="%d" width="12" height="12" fill="rgb(%d,%d,%d)" rx="2"/>`, sx, ly-10, c.R, c.G, c.B)
		fmt.Fprintf(w, `<text x="%d" y="%d" fill="#3A342A" stroke="white" stroke-width="2.5" paint-order="stroke">%s</text>`, sx+16, ly, item.label)
	}
	fmt.Fprintln(w, `</g>`)
	fmt.Fprintln(w, `</svg>`)
}
