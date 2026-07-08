// Package terrain renders standalone, print-quality route maps: an OSM-derived
// "normal" map (water, forests, landuse, roads, paths, labels) shaded with a
// hillshade computed from elevation data, with the trip's route drawn on top.
//
// The heavy lifting is delegated to external command-line tools that must be on
// PATH (or in the well-known fallback dirs): GDAL (gdalbuildvrt, gdalwarp,
// gdaldem, gdal_translate, ogr2ogr) for elevation and OSM geometry, osmium for
// fast bbox extraction, and rsvg-convert for rasterising the styled OSM SVG.
// Compositing and the route overlay are done in Go.
package terrain

import (
	"fmt"
	"image"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/disintegration/imaging"
	"github.com/paulmach/orb"
)

// mercatorR is half the circumference of the Earth in EPSG:3857 (Web Mercator)
// meters. Web Mercator maps the world onto a square spanning [-mercatorR,
// +mercatorR] on both axes, so it is the constant that converts slippy-tile
// pixel coordinates into projected meters. Value from the EPSG:3857 definition.
const mercatorR = 20037508.342789244

// candidateToolDirs are extra directories searched for the external binaries
// when they are not already on PATH. Postgres.app ships GDAL for PostGIS, and
// Homebrew is the usual source of osmium/rsvg-convert on macOS.
var candidateToolDirs = []string{
	"/Applications/Postgres.app/Contents/Versions/17/bin",
	"/Applications/Postgres.app/Contents/Latest/bin",
	"/opt/homebrew/bin",
	"/usr/local/bin",
}

// findTool resolves the absolute path to an external command-line tool,
// searching PATH first and then the well-known fallback locations. It returns an
// actionable error when the tool cannot be found.
func findTool(name string) (string, error) {
	if path, err := exec.LookPath(name); err == nil {
		return path, nil
	}
	for _, dir := range candidateToolDirs {
		candidate := filepath.Join(dir, name)
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
			return candidate, nil
		}
	}
	return "", fmt.Errorf("required tool %q not found on PATH or in %v — install it (GDAL: `brew install gdal`, osmium: `brew install osmium-tool`, rsvg: `brew install librsvg`)", name, candidateToolDirs)
}

// runTool executes an external tool and wraps any failure with the combined
// stdout/stderr, where these tools write their diagnostics.
func runTool(name string, args ...string) error {
	bin, err := findTool(name)
	if err != nil {
		return err
	}
	out, err := exec.Command(bin, args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s %s: %w\n%s", name, strings.Join(args, " "), err, out)
	}
	return nil
}

// srtmTilesFor returns the /vsigzip/ paths of the gzipped SRTM .hgt tiles that
// cover the given lat/lon bounding box. SRTM tiles are one degree square and
// named after their south-west corner (e.g. N52E017 covers 52..53N, 17..18E),
// so the covering set is every integer-degree cell the box touches. Missing
// tiles are skipped silently; the caller detects total absence downstream.
func srtmTilesFor(latMin, latMax, lonMin, lonMax float64, demDir string) []string {
	var tiles []string
	for lat := int(math.Floor(latMin)); lat <= int(math.Floor(latMax)); lat++ {
		for lon := int(math.Floor(lonMin)); lon <= int(math.Floor(lonMax)); lon++ {
			name := fmt.Sprintf("N%02dE%03d.hgt.gz", lat, lon)
			full := filepath.Join(demDir, name)
			if _, err := os.Stat(full); err == nil {
				// GDAL reads the gzip directly through its /vsigzip/ virtual
				// filesystem — no need to decompress to a temp file.
				tiles = append(tiles, "/vsigzip/"+full)
			}
		}
	}
	return tiles
}

// pixelToMercator converts a slippy-tile pixel coordinate at a given zoom into
// EPSG:3857 meters. The photo-map projection (svg package) places content in
// this same pixel space, so converting its bounds through this function yields
// the exact projected extent GDAL must render for the hillshade and OSM layers
// to line up pixel-for-pixel with the route overlay.
func pixelToMercator(px, py float64, zoom int) (x, y float64) {
	worldPx := 256.0 * math.Pow(2, float64(zoom))
	x = px/worldPx*(2*mercatorR) - mercatorR
	// Pixel Y grows downward (north at top); Mercator Y grows upward.
	y = mercatorR - py/worldPx*(2*mercatorR)
	return x, y
}

// mercExtent is an EPSG:3857 bounding box in meters.
type mercExtent struct {
	minX, minY, maxX, maxY float64
}

// demParams collects the inputs needed to render the shaded-relief layer.
type demParams struct {
	ext          mercExtent // EPSG:3857 extent to render
	pxW, pxH     int        // output raster resolution in pixels
	centerLat    float64    // for latitude-compensated vertical exaggeration
	source       string     // "nmt10" (10m GUGiK) or "srtm" (30m fallback)
	demDir       string     // directory of SRTM .hgt.gz tiles
	dtmDir       string     // directory of GUGiK 10m .i16.gz tiles
	latMin       float64    // lat/lon box, to select covering tiles
	latMax       float64
	lonMin       float64
	lonMax       float64
	exaggeration float64 // vertical exaggeration multiplier (>1 = punchier hills)
	drawContours bool    // generate contour lines (currently off by default)
}

// buildDEMSource prepares a GDAL-readable elevation dataset for the requested
// source, returning its path and the value scale (elevation = raw * scale) to
// fold into the hillshade z-factor. It prefers the 10m NMT tiles and falls back
// to 30m SRTM where the 10m grid has no coverage.
func buildDEMSource(p demParams, tmpDir string) (path string, scale float64, err error) {
	if p.source != "srtm" && p.dtmDir != "" {
		if tiles := nmtTilesFor(p.latMin, p.latMax, p.lonMin, p.lonMax, p.dtmDir); len(tiles) > 0 {
			return buildNMT10VRT(tiles, tmpDir)
		}
	}
	// SRTM fallback: mosaic the covering /vsigzip tiles.
	tiles := srtmTilesFor(p.latMin, p.latMax, p.lonMin, p.lonMax, p.demDir)
	if len(tiles) == 0 {
		return "", 0, fmt.Errorf("no elevation tiles (10m NMT or SRTM) cover lat %.3f..%.3f lon %.3f..%.3f",
			p.latMin, p.latMax, p.lonMin, p.lonMax)
	}
	vrt := filepath.Join(tmpDir, "srtm.vrt")
	if err := runTool("gdalbuildvrt", append([]string{vrt}, tiles...)...); err != nil {
		return "", 0, err
	}
	return vrt, 1.0, nil
}

// renderHillshade produces a grayscale multidirectional hillshade for the given
// extent as an in-memory image at the requested resolution. Elevation is used
// only for shading — the map surface itself comes from OSM. The hillshade is
// later multiplied over the OSM base to give it relief.
// contourLine is one contour polyline in EPSG:3857 meters, flagged as a major
// (index) contour when its elevation is a multiple of the major interval.
type contourLine struct {
	geom  orb.Geometry // LineString / MultiLineString in EPSG:3857
	major bool
}

// renderTerrain warps the elevation source once and derives both a grayscale
// hillshade image (at the requested pixel size) and a set of contour lines.
// Elevation is used only for shading and contours — the map surface is OSM.
func renderTerrain(p demParams) (image.Image, []contourLine, error) {
	tmp, err := os.MkdirTemp("", "terrain-dem-")
	if err != nil {
		return nil, nil, err
	}
	defer os.RemoveAll(tmp)

	warped := filepath.Join(tmp, "warped.tif")
	hsTif := filepath.Join(tmp, "hs.tif")
	hsPng := filepath.Join(tmp, "hs.png")

	// 1. Prepare the elevation source (10m NMT, or SRTM fallback). demScale
	//    converts the stored integer values to meters.
	src, demScale, err := buildDEMSource(p, tmp)
	if err != nil {
		return nil, nil, err
	}

	// 2. Reproject to Web Mercator and clip to the exact extent + pixel size so
	//    the result aligns with the slippy-pixel route overlay. Cubic resampling
	//    keeps the elevation surface smooth.
	if err := runTool("gdalwarp",
		"-t_srs", "EPSG:3857",
		"-te", ftoa(p.ext.minX), ftoa(p.ext.minY), ftoa(p.ext.maxX), ftoa(p.ext.maxY),
		"-ts", strconv.Itoa(p.pxW), strconv.Itoa(p.pxH),
		"-r", "cubic", "-overwrite", src, warped,
	); err != nil {
		return nil, nil, err
	}

	// 3. Multidirectional hillshade. The z-factor combines three things:
	//    - `exaggeration`: makes gentle relief legible;
	//    - 1/cos(latitude): Web Mercator inflates horizontal meters by 1/cos(lat)
	//      (~1.66x at 53°N), which would otherwise flatten every slope;
	//    - demScale: converts the source's stored units (e.g. NMT decimeters) to
	//      meters so the slope is physically correct.
	zFactor := p.exaggeration * demScale / math.Cos(p.centerLat*math.Pi/180.0)
	if err := runTool("gdaldem", "hillshade", "-multidirectional",
		"-z", ftoa(zFactor), "-compute_edges", warped, hsTif,
	); err != nil {
		return nil, nil, err
	}

	// 4. Translate to PNG so Go's image package can read it (no pure-Go GeoTIFF
	//    decoder in the stdlib).
	if err := runTool("gdal_translate", "-of", "PNG", hsTif, hsPng); err != nil {
		return nil, nil, err
	}
	hs, err := imaging.Open(hsPng)
	if err != nil {
		return nil, nil, fmt.Errorf("open hillshade png: %w", err)
	}

	// 5. Contours from the same warped DEM (optional). Values are still in the
	//    source's stored units, so scale the interval by demScale to get meters.
	if !p.drawContours {
		return hs, nil, nil
	}
	contours, err := generateContours(warped, demScale, tmp)
	if err != nil {
		return nil, nil, err
	}
	return hs, contours, nil
}

var minMaxRe = regexp.MustCompile(`Computed Min/Max=([-0-9.]+),([-0-9.]+)`)

// generateContours runs gdal_contour on the warped DEM and returns the contour
// polylines (in EPSG:3857). The interval is chosen from the elevation range so
// the map shows a legible ~10–20 lines rather than a solid mass or nothing.
func generateContours(warped string, demScale float64, tmp string) ([]contourLine, error) {
	// Elevation range in stored units (parse gdalinfo -mm).
	bin, err := findTool("gdalinfo")
	if err != nil {
		return nil, err
	}
	out, err := exec.Command(bin, "-mm", warped).CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("gdalinfo -mm: %w\n%s", err, out)
	}
	m := minMaxRe.FindStringSubmatch(string(out))
	if m == nil {
		return nil, nil // no stats (e.g. all-nodata) → no contours, not an error
	}
	lo, _ := strconv.ParseFloat(m[1], 64)
	hi, _ := strconv.ParseFloat(m[2], 64)
	rangeM := (hi - lo) * demScale
	interval := niceContourStep(rangeM / 15)
	if interval <= 0 {
		return nil, nil
	}
	// gdal_contour interval is in stored units; convert meters → stored units.
	storedInterval := interval / demScale

	geojson := filepath.Join(tmp, "contours.geojson")
	if err := runTool("gdal_contour", "-a", "elev", "-i", ftoa(storedInterval), warped, geojson); err != nil {
		return nil, err
	}
	feats, err := loadFeatures(geojson)
	if err != nil {
		return nil, err
	}
	majorEvery := interval * 5 // every 5th line is an index (major) contour
	lines := make([]contourLine, 0, len(feats))
	for _, f := range feats {
		elevStored, _ := strconv.ParseFloat(f.tags["elev"], 64)
		elevM := elevStored * demScale
		major := math.Mod(math.Abs(elevM)+interval/2, majorEvery) < interval
		lines = append(lines, contourLine{geom: f.geom, major: major})
	}
	return lines, nil
}

// niceContourStep rounds a rough interval up to a cartographically tidy value.
func niceContourStep(rough float64) float64 {
	steps := []float64{1, 2, 2.5, 5, 10, 20, 25, 50, 100, 200, 250, 500}
	for _, s := range steps {
		if rough <= s {
			return s
		}
	}
	return 1000
}

// clamp8 rounds and clamps a float to a 0..255 byte.
func clamp8(v float64) uint8 {
	if v < 0 {
		return 0
	}
	if v > 255 {
		return 255
	}
	return uint8(v + 0.5)
}

// ftoa formats a float for a command-line argument with enough precision for
// meter-scale extents.
func ftoa(v float64) string {
	return strconv.FormatFloat(v, 'f', 4, 64)
}
