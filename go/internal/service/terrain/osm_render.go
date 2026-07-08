package terrain

import (
	"fmt"
	"image"
	"io"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/disintegration/imaging"
	"github.com/paulmach/orb"
)

// lod (level of detail) controls how much the OSM base shows for a given output
// size, so the small web map and the big print map each get an appropriate
// density rather than one being a blind enlargement of the other.
type lod struct {
	minLabelRank      int     // drop place labels whose priority (z) is below this
	labelPadPx        float64 // extra collision padding around labels (ref-width px)
	minFeaturePx      float64 // skip area features smaller than this (output px)
	showMinorContours bool    // draw minor contours (not just index/major ones)
}

// Web map: sparser labels (no hamlets), roomy spacing, tiny features dropped,
// only bold index contours.
var lodWeb = lod{minLabelRank: 60, labelPadPx: 3.5, minFeaturePx: 4, showMinorContours: false}

// Print map: denser — keep hamlets, small features, and all contour lines.
var lodPrint = lod{minLabelRank: 50, labelPadPx: 2.0, minFeaturePx: 1.5, showMinorContours: true}

// renderOSMBase styles the OSM layers into an SVG and rasterizes it to an RGBA
// image at the projector's output size using rsvg-convert. The result is the
// "normal" map surface, which is later shaded by the hillshade. tag makes the
// temp filenames unique so the article and print passes don't collide.
func renderOSMBase(data *osmData, contours []contourLine, pr projector, tmpDir, tag string, l lod) (image.Image, error) {
	svgPath := filepath.Join(tmpDir, "osm_"+tag+".svg")
	pngPath := filepath.Join(tmpDir, "osm_"+tag+".png")

	f, err := os.Create(svgPath)
	if err != nil {
		return nil, fmt.Errorf("create osm svg: %w", err)
	}
	writeOSMSVG(f, data, contours, pr, l)
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
func writeOSMSVG(w io.Writer, data *osmData, contours []contourLine, pr projector, l lod) {
	width := int(pr.width)
	height := int(pr.height)

	fmt.Fprintf(w, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">`,
		width, height, width, height)
	fmt.Fprintln(w)
	fmt.Fprintf(w, `<rect x="0" y="0" width="%d" height="%d" fill="%s"/>`, width, height, mapBackground)
	fmt.Fprintln(w)
	// Round joins/caps everywhere read more natural for organic geometry.
	fmt.Fprintln(w, `<g stroke-linecap="round" stroke-linejoin="round">`)

	writePolygonLayer(w, data.polygons, pr, l.minFeaturePx)
	writeContourLayer(w, contours, pr, l)
	writeLineLayers(w, data.lines, pr)
	writeLabelLayer(w, data.points, pr, l)

	fmt.Fprintln(w, `</g>`)
	fmt.Fprintln(w, `</svg>`)
}

// writePolygonLayer draws all area features (fills + protected-area outlines),
// ordered by z so water and forest sit above farmland, etc.
func writePolygonLayer(w io.Writer, polys []osmFeature, pr projector, minFeaturePx float64) {
	type spec struct {
		f  osmFeature
		st fillStyle
		z  int
	}
	var specs []spec
	for _, f := range polys {
		st, z, ok := polygonSpec(f)
		if !ok || !inView(f.geom, pr) {
			continue
		}
		// Skip features too small to matter at this output size (declutter),
		// but never drop water — small ponds/lakes are landmarks worth keeping.
		if minFeaturePx > 0 && !st.noFill && st.color != "#7FBFEA" && featurePxSize(f.geom, pr) < minFeaturePx {
			continue
		}
		specs = append(specs, spec{f, st, z})
	}
	sort.SliceStable(specs, func(i, j int) bool { return specs[i].z < specs[j].z })

	for _, s := range specs {
		d := polygonPath(s.f.geom, pr)
		if d == "" {
			continue
		}
		if s.st.noFill {
			fmt.Fprintf(w, `<path d="%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-dasharray="%s" opacity="%.2f"/>`,
				d, s.st.outlineColor, s.st.outlineWidth, s.st.outlineDash, s.st.opacity)
		} else {
			fmt.Fprintf(w, `<path d="%s" fill="%s" fill-rule="evenodd" opacity="%.2f"/>`, d, s.st.color, s.st.opacity)
		}
		fmt.Fprintln(w)
	}
}

// writeContourLayer draws elevation contours as faint brown lines between the
// landcover and the roads. Minor contours are hair-thin and only shown at print
// LOD; major (index) contours are slightly bolder. Lines are RDP-simplified to
// tame the wiggle of the 10m DEM.
func writeContourLayer(w io.Writer, contours []contourLine, pr projector, l lod) {
	if len(contours) == 0 {
		return
	}
	eps := 1.5
	for _, c := range contours {
		if !c.major && !l.showMinorContours {
			continue
		}
		color, width, opacity := "#AD8A5E", 0.35, 0.32
		if c.major {
			color, width, opacity = "#9C744A", 0.7, 0.5
		}
		for _, ls := range contourLineStrings(c.geom) {
			pts := make([][2]float64, 0, len(ls))
			for _, p := range ls {
				x, y := pr.projectMercator(p[0], p[1])
				pts = append(pts, [2]float64{x, y})
			}
			pts = rdpSimplify(pts, eps)
			if len(pts) < 2 {
				continue
			}
			fmt.Fprintf(w, `<polyline points="%s" fill="none" stroke="%s" stroke-width="%.2f" opacity="%.2f"/>`,
				polylinePoints(pts), color, width, opacity)
			fmt.Fprintln(w)
		}
	}
}

// contourLineStrings flattens a contour geometry (Line or MultiLine) into raw
// EPSG:3857 coordinate slices.
func contourLineStrings(g orb.Geometry) [][][2]float64 {
	switch geom := g.(type) {
	case orb.LineString:
		out := make([][2]float64, len(geom))
		for i, p := range geom {
			out[i] = [2]float64{p[0], p[1]}
		}
		return [][][2]float64{out}
	case orb.MultiLineString:
		var res [][][2]float64
		for _, ls := range geom {
			out := make([][2]float64, len(ls))
			for i, p := range ls {
				out[i] = [2]float64{p[0], p[1]}
			}
			res = append(res, out)
		}
		return res
	}
	return nil
}

// writeLineLayers draws line features in bands: waterways, then paths/tracks,
// then road casings, then road cores, then railways on top.
func writeLineLayers(w io.Writer, lines []osmFeature, pr projector) {
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

	// Widths are absolute output pixels (same on the article and print maps, so
	// the print map is finer detail rather than a 3x enlargement). Roads are
	// narrowed to roadWidthScale of their nominal weight.
	for _, s := range specs {
		if s.cat == catWaterway {
			stroke(linePath(s.f.geom, pr), s.st.color, s.st.width, s.st.dash, s.st.opacity)
		}
	}
	// Band 2: paths / tracks / cycleways.
	for _, s := range specs {
		if s.cat == catPath {
			stroke(linePath(s.f.geom, pr), s.st.color, s.st.width, s.st.dash, s.st.opacity)
		}
	}
	// Band 3: road casings (drawn beneath cores).
	for _, s := range specs {
		if s.cat == catRoad && s.st.casingWidth > 0 {
			stroke(linePath(s.f.geom, pr), s.st.casingColor, s.st.casingWidth*roadWidthScale, "", s.st.opacity)
		}
	}
	// Band 4: road cores.
	for _, s := range specs {
		if s.cat == catRoad {
			stroke(linePath(s.f.geom, pr), s.st.color, s.st.width*roadWidthScale, s.st.dash, s.st.opacity)
		}
	}
	// Band 5: railways (casing then dashed core for the classic look).
	for _, s := range specs {
		if s.cat == catRailway {
			d := linePath(s.f.geom, pr)
			stroke(d, s.st.color, s.st.width, "", s.st.opacity)
			stroke(d, s.st.casingColor, s.st.casingWidth, s.st.dash, s.st.opacity)
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
func writeLabelLayer(w io.Writer, points []osmFeature, pr projector, l lod) {
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
		if !ok || z < l.minLabelRank {
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
		fontSize := s.fontPx
		pad := l.labelPadPx
		// Rough text metrics: average glyph ~0.55em wide, ~1.2em tall, plus a
		// LOD-controlled padding so labels keep their distance.
		halfW := float64(len([]rune(s.text)))*fontSize*0.55/2 + pad
		halfH := fontSize*1.2/2 + pad
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
			r := 3.0
			fmt.Fprintf(w, `<path d="M %.1f,%.1f L %.1f,%.1f L %.1f,%.1f Z" fill="#7A5230" stroke="white" stroke-width="%.2f"/>`,
				s.x, s.y-r, s.x-r*0.9, s.y+r*0.7, s.x+r*0.9, s.y+r*0.7, 0.4)
			fmt.Fprintln(w)
		}
		fontSize := s.fontPx
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

// featurePxSize returns the larger of a geometry's projected bounding-box width
// and height in output pixels — a cheap proxy for "how big does this draw".
func featurePxSize(g orb.Geometry, pr projector) float64 {
	b := g.Bound()
	x0, y0 := pr.project(b.Min.Lat(), b.Min.Lon())
	x1, y1 := pr.project(b.Max.Lat(), b.Max.Lon())
	return math.Max(math.Abs(x1-x0), math.Abs(y1-y0))
}

// escapeXML escapes the handful of characters that break SVG text content.
func escapeXML(s string) string {
	r := strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;")
	return r.Replace(s)
}
