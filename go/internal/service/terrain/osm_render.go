package terrain

import (
	"fmt"
	"image"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/disintegration/imaging"
	"github.com/paulmach/orb"
)

// renderOSMBase styles the OSM layers into an SVG and rasterizes it to an RGBA
// image at the projector's output size using rsvg-convert. The result is the
// "normal" map surface, which is later shaded by the hillshade.
func renderOSMBase(data *osmData, pr projector, tmpDir string) (image.Image, error) {
	svgPath := filepath.Join(tmpDir, "osm.svg")
	pngPath := filepath.Join(tmpDir, "osm.png")

	f, err := os.Create(svgPath)
	if err != nil {
		return nil, fmt.Errorf("create osm svg: %w", err)
	}
	writeOSMSVG(f, data, pr)
	if err := f.Close(); err != nil {
		return nil, err
	}

	w := int(pr.width)
	h := int(pr.height)
	if err := runTool("rsvg-convert", "-w", strconv.Itoa(w), "-h", strconv.Itoa(h),
		"-o", pngPath, svgPath); err != nil {
		return nil, err
	}
	img, err := imaging.Open(pngPath)
	if err != nil {
		return nil, fmt.Errorf("open rasterized osm png: %w", err)
	}
	return img, nil
}

// writeOSMSVG emits the full styled OSM map (no route, no hillshade) as an SVG
// in the projector's pixel space, using the painter's-algorithm order.
func writeOSMSVG(w io.Writer, data *osmData, pr projector) {
	width := int(pr.width)
	height := int(pr.height)
	scale := pr.scale()

	fmt.Fprintf(w, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">`,
		width, height, width, height)
	fmt.Fprintln(w)
	fmt.Fprintf(w, `<rect x="0" y="0" width="%d" height="%d" fill="%s"/>`, width, height, mapBackground)
	fmt.Fprintln(w)
	// Round joins/caps everywhere read more natural for organic geometry.
	fmt.Fprintln(w, `<g stroke-linecap="round" stroke-linejoin="round">`)

	writePolygonLayer(w, data.polygons, pr)
	writeLineLayers(w, data.lines, pr, scale)
	writeLabelLayer(w, data.points, pr, scale)

	fmt.Fprintln(w, `</g>`)
	fmt.Fprintln(w, `</svg>`)
}

// writePolygonLayer draws all area features (fills + protected-area outlines),
// ordered by z so water and forest sit above farmland, etc.
func writePolygonLayer(w io.Writer, polys []osmFeature, pr projector) {
	type spec struct {
		f  osmFeature
		st fillStyle
		z  int
	}
	var specs []spec
	for _, f := range polys {
		if st, z, ok := polygonSpec(f); ok && inView(f.geom, pr) {
			specs = append(specs, spec{f, st, z})
		}
	}
	sort.SliceStable(specs, func(i, j int) bool { return specs[i].z < specs[j].z })

	for _, s := range specs {
		d := polygonPath(s.f.geom, pr)
		if d == "" {
			continue
		}
		if s.st.noFill {
			fmt.Fprintf(w, `<path d="%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-dasharray="%s" opacity="%.2f"/>`,
				d, s.st.outlineColor, s.st.outlineWidth*pr.scale(), scaleDash(s.st.outlineDash, pr.scale()), s.st.opacity)
		} else {
			fmt.Fprintf(w, `<path d="%s" fill="%s" fill-rule="evenodd" opacity="%.2f"/>`, d, s.st.color, s.st.opacity)
		}
		fmt.Fprintln(w)
	}
}

// writeLineLayers draws line features in bands: waterways, then paths/tracks,
// then road casings, then road cores, then railways on top.
func writeLineLayers(w io.Writer, lines []osmFeature, pr projector, scale float64) {
	type spec struct {
		f   osmFeature
		cat lineCategory
		st  lineStyle
		z   int
	}
	var specs []spec
	for _, f := range lines {
		if cat, st, z, ok := lineSpec(f); ok && inView(f.geom, pr) {
			specs = append(specs, spec{f, cat, st, z})
		}
	}
	sort.SliceStable(specs, func(i, j int) bool { return specs[i].z < specs[j].z })

	stroke := func(d string, color string, width float64, dash string, opacity float64) {
		if d == "" || width <= 0 {
			return
		}
		fmt.Fprintf(w, `<path d="%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-dasharray="%s" opacity="%.2f"/>`,
			d, color, width, dash, opacity)
		fmt.Fprintln(w)
	}

	// Band 1: waterways.
	for _, s := range specs {
		if s.cat == catWaterway {
			stroke(linePath(s.f.geom, pr), s.st.color, s.st.width*scale, scaleDash(s.st.dash, scale), s.st.opacity)
		}
	}
	// Band 2: paths / tracks / cycleways.
	for _, s := range specs {
		if s.cat == catPath {
			stroke(linePath(s.f.geom, pr), s.st.color, s.st.width*scale, scaleDash(s.st.dash, scale), s.st.opacity)
		}
	}
	// Band 3: road casings (drawn beneath cores).
	for _, s := range specs {
		if s.cat == catRoad && s.st.casingWidth > 0 {
			stroke(linePath(s.f.geom, pr), s.st.casingColor, s.st.casingWidth*scale, "", s.st.opacity)
		}
	}
	// Band 4: road cores.
	for _, s := range specs {
		if s.cat == catRoad {
			stroke(linePath(s.f.geom, pr), s.st.color, s.st.width*scale, scaleDash(s.st.dash, scale), s.st.opacity)
		}
	}
	// Band 5: railways (casing then dashed core for the classic look).
	for _, s := range specs {
		if s.cat == catRailway {
			d := linePath(s.f.geom, pr)
			stroke(d, s.st.color, s.st.width*scale, "", s.st.opacity)
			stroke(d, s.st.casingColor, s.st.casingWidth*scale, scaleDash(s.st.dash, scale), s.st.opacity)
		}
	}
}

// labelBox is a placed label's bounding rectangle, used for collision testing.
type labelBox struct {
	minX, minY, maxX, maxY float64
}

func (a labelBox) overlaps(b labelBox) bool {
	return a.minX < b.maxX && a.maxX > b.minX && a.minY < b.maxY && a.maxY > b.minY
}

// writeLabelLayer draws place-name labels and peak/viewpoint markers on top,
// each with a white halo (paint-order) for legibility. Labels are placed
// greedily by priority (peaks/cities first): a label is skipped if its box
// overlaps one already placed, so dense areas stay legible instead of turning
// into a wall of overlapping text.
func writeLabelLayer(w io.Writer, points []osmFeature, pr projector, scale float64) {
	type spec struct {
		text   string
		x, y   float64
		fontPx float64
		marker bool
		z      int
	}
	var specs []spec
	seen := map[string]bool{}
	for _, f := range points {
		text, fontPx, marker, z, ok := placeLabel(f)
		if !ok {
			continue
		}
		pt, isPt := f.geom.(orb.Point)
		if !isPt {
			continue
		}
		x, y := pr.project(pt.Lat(), pt.Lon())
		if x < 0 || x > pr.width || y < 0 || y > pr.height {
			continue
		}
		if seen[text] {
			continue
		}
		seen[text] = true
		specs = append(specs, spec{text, x, y, fontPx, marker, z})
	}
	// Place higher-priority labels (peaks, cities) first so they win collisions;
	// lower-priority labels that would overlap are dropped.
	sort.SliceStable(specs, func(i, j int) bool { return specs[i].z > specs[j].z })

	var placed []labelBox
	kept := specs[:0]
	for _, s := range specs {
		fontSize := s.fontPx * scale
		// Rough text metrics: average glyph ~0.55em wide, ~1.2em tall.
		halfW := float64(len([]rune(s.text))) * fontSize * 0.55 / 2
		halfH := fontSize * 1.2 / 2
		box := labelBox{s.x - halfW, s.y - halfH, s.x + halfW, s.y + halfH}
		collides := false
		for _, p := range placed {
			if box.overlaps(p) {
				collides = true
				break
			}
		}
		if collides {
			continue
		}
		placed = append(placed, box)
		kept = append(kept, s)
	}
	specs = kept

	// Draw lowest-priority first so higher-priority text paints on top.
	sort.SliceStable(specs, func(i, j int) bool { return specs[i].z < specs[j].z })

	for _, s := range specs {
		if s.marker {
			// Small brown triangle for peaks/viewpoints.
			r := 3.0 * scale
			fmt.Fprintf(w, `<path d="M %.1f,%.1f L %.1f,%.1f L %.1f,%.1f Z" fill="#7A5230" stroke="white" stroke-width="%.2f"/>`,
				s.x, s.y-r, s.x-r*0.9, s.y+r*0.7, s.x+r*0.9, s.y+r*0.7, 0.4*scale)
			fmt.Fprintln(w)
		}
		fontSize := s.fontPx * scale
		dy := -fontSize * 0.6
		if s.marker {
			dy = -fontSize * 0.8
		}
		fmt.Fprintf(w, `<text x="%.1f" y="%.1f" font-family="sans-serif" font-size="%.2f" `+
			`text-anchor="middle" fill="#3A342A" stroke="white" stroke-width="%.2f" `+
			`paint-order="stroke" stroke-linejoin="round">%s</text>`,
			s.x, s.y+dy, fontSize, fontSize*0.28, escapeXML(s.text))
		fmt.Fprintln(w)
	}
}

// --- geometry → SVG path helpers (project lon/lat into output pixels) ---

// polygonPath builds an SVG path (with holes via sub-paths) for a Polygon or
// MultiPolygon geometry. Returns "" for other geometry types.
func polygonPath(g orb.Geometry, pr projector) string {
	var sb strings.Builder
	switch geom := g.(type) {
	case orb.Polygon:
		writeRings(&sb, geom, pr)
	case orb.MultiPolygon:
		for _, poly := range geom {
			writeRings(&sb, poly, pr)
		}
	default:
		return ""
	}
	return sb.String()
}

func writeRings(sb *strings.Builder, poly orb.Polygon, pr projector) {
	for _, ring := range poly {
		if len(ring) < 3 {
			continue
		}
		for i, p := range ring {
			x, y := pr.project(p.Lat(), p.Lon())
			if i == 0 {
				fmt.Fprintf(sb, "M %.1f,%.1f", x, y)
			} else {
				fmt.Fprintf(sb, " L %.1f,%.1f", x, y)
			}
		}
		sb.WriteString(" Z ")
	}
}

// linePath builds an SVG path for a LineString or MultiLineString geometry.
func linePath(g orb.Geometry, pr projector) string {
	var sb strings.Builder
	switch geom := g.(type) {
	case orb.LineString:
		writeLineString(&sb, geom, pr)
	case orb.MultiLineString:
		for _, ls := range geom {
			writeLineString(&sb, ls, pr)
		}
	default:
		return ""
	}
	return sb.String()
}

func writeLineString(sb *strings.Builder, ls orb.LineString, pr projector) {
	if len(ls) < 2 {
		return
	}
	for i, p := range ls {
		x, y := pr.project(p.Lat(), p.Lon())
		if i == 0 {
			fmt.Fprintf(sb, "M %.1f,%.1f", x, y)
		} else {
			fmt.Fprintf(sb, " L %.1f,%.1f", x, y)
		}
	}
	sb.WriteString(" ")
}

// inView reports whether a geometry's bounding box overlaps the output canvas,
// used to cull off-screen features and keep the SVG small.
func inView(g orb.Geometry, pr projector) bool {
	b := g.Bound()
	x0, y0 := pr.project(b.Min.Lat(), b.Min.Lon())
	x1, y1 := pr.project(b.Max.Lat(), b.Max.Lon())
	if x0 > x1 {
		x0, x1 = x1, x0
	}
	if y0 > y1 {
		y0, y1 = y1, y0
	}
	return x1 >= 0 && x0 <= pr.width && y1 >= 0 && y0 <= pr.height
}

// scaleDash multiplies each number in an SVG dasharray by scale. Empty stays
// empty (solid).
func scaleDash(dash string, scale float64) string {
	if dash == "" {
		return ""
	}
	parts := strings.Split(dash, ",")
	for i, p := range parts {
		if v, err := strconv.ParseFloat(strings.TrimSpace(p), 64); err == nil {
			parts[i] = strconv.FormatFloat(v*scale, 'f', 2, 64)
		}
	}
	return strings.Join(parts, ",")
}

// escapeXML escapes the handful of characters that break SVG text content.
func escapeXML(s string) string {
	r := strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;")
	return r.Replace(s)
}
