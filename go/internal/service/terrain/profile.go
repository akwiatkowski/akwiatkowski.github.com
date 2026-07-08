package terrain

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"

	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
)

// Elevation-profile chart dimensions (standalone SVG, fixed size).
const (
	profileWidth   = 1000
	profileHeight  = 280
	profileMLeft   = 52 // room for elevation labels
	profileMRight  = 16
	profileMTop    = 16
	profileMBottom = 30 // room for distance labels
)

// profileSample is one point along the route: cumulative distance (km) and
// elevation (m).
type profileSample struct {
	dist float64
	elev float64
}

// RenderElevationProfile samples the route's elevation from the 10m NMT tiles
// and writes an SVG altitude graph (distance × elevation) to the per-post map
// dir as "<slug>-elevation.svg". Returns the output path.
func RenderElevationProfile(post *model.Post, opts Options) (string, error) {
	opts = opts.withDefaults()
	if !post.HasRoutes() {
		return "", fmt.Errorf("post %q has no route data", post.Slug)
	}

	// Gather route points in order and their lat/lon bounding box.
	var lats, lons []float64
	latMin, lonMin := math.Inf(1), math.Inf(1)
	latMax, lonMax := math.Inf(-1), math.Inf(-1)
	for _, route := range post.Routes {
		for _, seg := range route.Segments {
			for _, ll := range seg {
				lats = append(lats, ll.Lat)
				lons = append(lons, ll.Lon)
				latMin, latMax = math.Min(latMin, ll.Lat), math.Max(latMax, ll.Lat)
				lonMin, lonMax = math.Min(lonMin, ll.Lon), math.Max(lonMax, ll.Lon)
			}
		}
	}
	if len(lats) < 2 {
		return "", fmt.Errorf("route for %q has too few points", post.Slug)
	}

	sampler, err := newElevationSampler(latMin, latMax, lonMin, lonMax, opts.DTMDir)
	if err != nil {
		return "", err
	}

	// Build (cumulative distance, elevation) with no-data points marked, then
	// fill gaps by linear interpolation from valid neighbors.
	elevs := make([]float64, len(lats))
	ok := make([]bool, len(lats))
	dist := make([]float64, len(lats))
	for i := range lats {
		if i > 0 {
			dist[i] = dist[i-1] + haversineKm(lats[i-1], lons[i-1], lats[i], lons[i])
		}
		elevs[i], ok[i] = sampler.at(lats[i], lons[i])
	}
	if !fillGaps(elevs, ok, dist) {
		return "", fmt.Errorf("no elevation data along route for %q", post.Slug)
	}

	samples := make([]profileSample, len(lats))
	for i := range lats {
		samples[i] = profileSample{dist: dist[i], elev: elevs[i]}
	}

	outURL := router.PostMapPath(post, "-elevation.svg")
	outPath := filepath.Join(opts.OutputDir, filepath.FromSlash(strings.TrimPrefix(outURL, "/")))
	if err := os.MkdirAll(filepath.Dir(outPath), 0o755); err != nil {
		return "", fmt.Errorf("create output dir: %w", err)
	}
	f, err := os.Create(outPath)
	if err != nil {
		return "", fmt.Errorf("create elevation svg: %w", err)
	}
	defer f.Close()
	writeProfileSVG(f, samples)
	return outPath, nil
}

// fillGaps replaces no-data elevations (ok=false) by linear interpolation over
// distance between the nearest valid samples. Returns false if there is no valid
// sample at all.
func fillGaps(elev []float64, ok []bool, dist []float64) bool {
	first := -1
	for i, v := range ok {
		if v {
			first = i
			break
		}
	}
	if first == -1 {
		return false
	}
	// Back-fill the leading gap and forward-fill the trailing gap with the
	// nearest valid value; interpolate interior gaps.
	for i := 0; i < first; i++ {
		elev[i] = elev[first]
	}
	last := first
	for i := first + 1; i < len(ok); i++ {
		if ok[i] {
			if i > last+1 {
				// interpolate (last, i) exclusive
				span := dist[i] - dist[last]
				for j := last + 1; j < i; j++ {
					t := 0.0
					if span > 0 {
						t = (dist[j] - dist[last]) / span
					}
					elev[j] = elev[last] + (elev[i]-elev[last])*t
				}
			}
			last = i
		}
	}
	for i := last + 1; i < len(ok); i++ {
		elev[i] = elev[last]
	}
	return true
}

// writeProfileSVG renders the altitude graph: a green area under the elevation
// line, min/max elevation gridlines, distance ticks, and a title summarizing
// total distance, total ascent, and the elevation range.
func writeProfileSVG(w *os.File, samples []profileSample) {
	minE, maxE := samples[0].elev, samples[0].elev
	var ascent float64
	for i, s := range samples {
		minE = math.Min(minE, s.elev)
		maxE = math.Max(maxE, s.elev)
		if i > 0 && s.elev > samples[i-1].elev {
			ascent += s.elev - samples[i-1].elev
		}
	}
	totalDist := samples[len(samples)-1].dist
	// Pad the elevation range so the line doesn't touch the frame.
	pad := math.Max(5, (maxE-minE)*0.1)
	lo, hi := minE-pad, maxE+pad

	plotW := float64(profileWidth - profileMLeft - profileMRight)
	plotH := float64(profileHeight - profileMTop - profileMBottom)
	baseY := float64(profileMTop) + plotH
	x := func(d float64) float64 {
		if totalDist == 0 {
			return float64(profileMLeft)
		}
		return float64(profileMLeft) + d/totalDist*plotW
	}
	y := func(e float64) float64 {
		return float64(profileMTop) + (1-(e-lo)/(hi-lo))*plotH
	}

	var line strings.Builder
	for i, s := range samples {
		cmd := "L"
		if i == 0 {
			cmd = "M"
		}
		fmt.Fprintf(&line, "%s%.1f,%.1f ", cmd, x(s.dist), y(s.elev))
	}
	fmt.Fprintf(w, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d" font-family="sans-serif">`,
		profileWidth, profileHeight, profileWidth, profileHeight)
	fmt.Fprintln(w)
	fmt.Fprintln(w, `<defs><linearGradient id="elev-fill" x1="0" y1="0" x2="0" y2="1">`+
		`<stop offset="0" stop-color="#8FC56E" stop-opacity="0.85"/>`+
		`<stop offset="1" stop-color="#8FC56E" stop-opacity="0.15"/></linearGradient></defs>`)
	fmt.Fprintf(w, `<rect x="0" y="0" width="%d" height="%d" fill="#F7F4EC"/>`, profileWidth, profileHeight)
	fmt.Fprintln(w)

	// Horizontal gridlines + elevation labels at lo/mid/hi (rounded to data).
	for _, e := range []float64{minE, (minE + maxE) / 2, maxE} {
		yy := y(e)
		fmt.Fprintf(w, `<line x1="%d" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#D8D2C2" stroke-width="1"/>`,
			profileMLeft, yy, float64(profileWidth-profileMRight), yy)
		fmt.Fprintf(w, `<text x="%d" y="%.1f" font-size="11" fill="#7A7462" text-anchor="end">%.0f</text>`,
			profileMLeft-6, yy+3, e)
		fmt.Fprintln(w)
	}

	// Area + line.
	fmt.Fprintf(w, `<path d="M%.1f,%.1f %sL%.1f,%.1f Z" fill="url(#elev-fill)"/>`,
		x(0), baseY, strings.TrimPrefix(line.String(), "M"), x(totalDist), baseY)
	fmt.Fprintln(w)
	fmt.Fprintf(w, `<path d="%s" fill="none" stroke="#4F8A3D" stroke-width="1.8" stroke-linejoin="round"/>`,
		strings.TrimSpace(line.String()))
	fmt.Fprintln(w)

	// Distance ticks (0 and total).
	fmt.Fprintf(w, `<text x="%d" y="%d" font-size="11" fill="#7A7462">0 km</text>`,
		profileMLeft, profileHeight-10)
	fmt.Fprintf(w, `<text x="%.0f" y="%d" font-size="11" fill="#7A7462" text-anchor="end">%.1f km</text>`,
		float64(profileWidth-profileMRight), profileHeight-10, totalDist)
	fmt.Fprintln(w)

	// Title / summary.
	fmt.Fprintf(w, `<text x="%d" y="%d" font-size="13" fill="#3A342A" font-weight="bold">%.1f km · ↑ %.0f m · %.0f–%.0f m n.p.m.</text>`,
		profileMLeft, profileMTop-3, totalDist, ascent, minE, maxE)
	fmt.Fprintln(w)

	fmt.Fprintln(w, `</svg>`)
}
