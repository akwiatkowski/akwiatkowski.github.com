package terrain

import (
	"encoding/json"
	"fmt"
	"image"
	"math"
	"os"
	"path/filepath"
	"strings"

	"github.com/disintegration/imaging"

	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/service/svg"
)

// Default rendering parameters. All are overridable through Options; zero values
// fall back to these so callers (the test command now, a pipeline node later)
// can pass a mostly-empty Options.
const (
	defaultArticleWidth  = 1000 // matches the blog's article-size photos
	defaultPrintScale    = 3    // print map = 3x the article map (retina / print DPI)
	defaultExaggeration  = 1.4  // vertical exaggeration for gentle lowland relief
	defaultMinZoom       = 8
	defaultMaxZoom       = 14   // beyond ~14 the 30m SRTM adds no real detail
	defaultShadeStrength = 0.45 // how strongly the hillshade darkens the OSM base
	defaultOSMMarginDeg  = 0.03
)

// Options configures a terrain-map render.
type Options struct {
	OutputDir     string  // site output root, e.g. env/dev/public/local
	DEMSource     string  // "nmt10" (10m GUGiK, default) or "srtm" (30m)
	DEMDir        string  // directory of SRTM .hgt.gz tiles
	DTMDir        string  // directory of GUGiK 10m .i16.gz tiles
	OSMPBFPath    string  // path to the source .osm.pbf (required)
	OSMCacheDir   string  // where extracted per-bbox GeoJSON is cached
	OSMMarginDeg  float64 // bbox margin (degrees) for the OSM extract (default 0.03)
	ArticleWidth  int     // web/article map width in px (default 1000)
	PrintScale    int     // print map is this multiple of the article map (default 3)
	Exaggeration  float64 // vertical exaggeration (default 1.4)
	ShadeStrength float64 // hillshade darkening strength 0..1 (default 0.5)
	DrawContours  bool    // draw elevation contour lines (default off)
	MinZoom       int     // clamp for zoom fitting (default 8)
	MaxZoom       int     // clamp for zoom fitting (default 14)
	Verbose       bool
}

// withDefaults returns a copy of o with zero fields replaced by defaults.
func (o Options) withDefaults() Options {
	if o.ArticleWidth == 0 {
		o.ArticleWidth = defaultArticleWidth
	}
	if o.PrintScale == 0 {
		o.PrintScale = defaultPrintScale
	}
	if o.Exaggeration == 0 {
		o.Exaggeration = defaultExaggeration
	}
	if o.MinZoom == 0 {
		o.MinZoom = defaultMinZoom
	}
	if o.MaxZoom == 0 {
		o.MaxZoom = defaultMaxZoom
	}
	if o.ShadeStrength == 0 {
		o.ShadeStrength = defaultShadeStrength
	}
	if o.OSMMarginDeg == 0 {
		o.OSMMarginDeg = defaultOSMMarginDeg
	}
	if o.OSMCacheDir == "" {
		o.OSMCacheDir = filepath.Join(os.TempDir(), "odkrywajac-terrain-osm")
	}
	if o.DEMSource == "" {
		o.DEMSource = "nmt10"
	}
	return o
}

// Result reports the files written and the geometry chosen for one render.
type Result struct {
	SVGPath      string
	PNGPath      string
	LargePNGPath string
	BgPath       string
	JSONPath     string
	Zoom         int
	Width        int
	Height       int
	LargeWidth   int
	LargeHeight  int
	// Gradient variant (empty when no elevation data covered the route).
	GradientSVGPath   string
	GradientPNGPath   string
	GradientLargePath string
}

// CheckAvailable reports whether everything the terrain renderer needs is
// present: the external tools on PATH (GDAL, osmium, rsvg-convert) and the input
// data (the OSM PBF and at least one DEM directory). The build uses this to skip
// terrain rendering with a clear message on machines without the geo toolchain
// or the large input files, rather than failing the whole build.
func CheckAvailable(opts Options) error {
	opts = opts.withDefaults()
	for _, tool := range []string{"gdalinfo", "gdalwarp", "gdaldem", "gdalbuildvrt", "gdal_translate", "ogr2ogr", "osmium", "rsvg-convert"} {
		if _, err := findTool(tool); err != nil {
			return err
		}
	}
	if opts.OSMPBFPath == "" {
		return fmt.Errorf("no OSM PBF path configured")
	}
	if _, err := os.Stat(opts.OSMPBFPath); err != nil {
		return fmt.Errorf("OSM PBF not found: %s", opts.OSMPBFPath)
	}
	_, dtmErr := os.Stat(opts.DTMDir)
	_, demErr := os.Stat(opts.DEMDir)
	if dtmErr != nil && demErr != nil {
		return fmt.Errorf("no DEM directory found (10m %q or SRTM %q)", opts.DTMDir, opts.DEMDir)
	}
	return nil
}

// Render produces a shaded-relief route map for a single post and writes its
// variants into the shared per-post map dir (router.PostMapPath): the SVG,
// screen PNG, hi-res "-large" PNG, route-free "-bg" PNG, and a ".json"
// georeference sidecar. Existing files are overwritten.
//
// It is the single entry point shared by the `terrain-map` test command and the
// build's renderTerrainMaps step, which calls it per post after the SVG maps.
func Render(post *model.Post, routeColors map[string]model.RouteColor, opts Options) (*Result, error) {
	opts = opts.withDefaults()

	if !post.HasRoutes() {
		return nil, fmt.Errorf("post %q has no route data", post.Slug)
	}

	// 1. Collect route points and their lat/lon bounding box.
	var points [][2]float64
	latMin, lonMin := math.Inf(1), math.Inf(1)
	latMax, lonMax := math.Inf(-1), math.Inf(-1)
	for _, route := range post.Routes {
		for _, seg := range route.Segments {
			for _, ll := range seg {
				points = append(points, [2]float64{ll.Lat, ll.Lon})
				latMin, latMax = math.Min(latMin, ll.Lat), math.Max(latMax, ll.Lat)
				lonMin, lonMax = math.Min(lonMin, ll.Lon), math.Max(lonMax, ll.Lon)
			}
		}
	}

	// 2. Fit a slippy-tile zoom and compute the padded crop rectangle in world
	//    pixels — reusing the photo-map projection so geometry matches exactly.
	zoom := svg.FitZoom(latMin, latMax, lonMin, lonMax, float64(opts.ArticleWidth), opts.MinZoom, opts.MaxZoom)
	bounds := svg.ComputeMapBounds(points, zoom, svg.BoundsPadding)
	cropW := bounds.Width()
	cropH := bounds.Height()
	if cropW <= 0 || cropH <= 0 {
		return nil, fmt.Errorf("degenerate route bounds for post %q", post.Slug)
	}

	// 3. Output dimensions (article + print), preserving the crop aspect ratio.
	articleW := opts.ArticleWidth
	articleH := int(math.Round(float64(articleW) * cropH / cropW))
	printW := articleW * opts.PrintScale
	printH := articleH * opts.PrintScale

	// 4. EPSG:3857 extent of the crop rectangle — what GDAL must render.
	minX, maxY := pixelToMercator(bounds.MinPX, bounds.MinPY, zoom) // top-left
	maxX, minY := pixelToMercator(bounds.MaxPX, bounds.MaxPY, zoom) // bottom-right
	ext := mercExtent{minX: minX, minY: minY, maxX: maxX, maxY: maxY}

	if opts.Verbose {
		fmt.Printf("terrain: %s zoom=%d article=%dx%d print=%dx%d lat %.4f..%.4f lon %.4f..%.4f\n",
			post.Slug, zoom, articleW, articleH, printW, printH, latMin, latMax, lonMin, lonMax)
	}

	// 5. Build the base maps. The map surface is OSM, shaded by the hillshade.
	//    The article and print maps are rendered independently at their own level
	//    of detail (print shows more labels/small features) — not one enlarged.
	tmp, err := os.MkdirTemp("", "terrain-render-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(tmp)

	printPr := projector{zoom: zoom, minPX: bounds.MinPX, minPY: bounds.MinPY, cropW: cropW, cropH: cropH, width: float64(printW), height: float64(printH)}
	articlePr := projector{zoom: zoom, minPX: bounds.MinPX, minPY: bounds.MinPY, cropW: cropW, cropH: cropH, width: float64(articleW), height: float64(articleH)}

	// Fetch OSM over the *rendered* extent (not just the route bbox) plus a
	// margin, so roads/features reach the visible edges instead of being clipped.
	rLatMax, rLonMin := svg.PixelToLatLon(bounds.MinPX, bounds.MinPY, zoom) // top-left
	rLatMin, rLonMax := svg.PixelToLatLon(bounds.MaxPX, bounds.MaxPY, zoom) // bottom-right
	osm, err := loadOSM(rLatMin, rLatMax, rLonMin, rLonMax, opts.OSMPBFPath, opts.OSMMarginDeg, opts.OSMCacheDir)
	if err != nil {
		return nil, err
	}

	// Hillshade + contours once at print resolution; downscale shade for article.
	shadePrint, contours, err := renderTerrain(demParams{
		ext:          ext,
		pxW:          printW,
		pxH:          printH,
		centerLat:    (latMin + latMax) / 2,
		source:       opts.DEMSource,
		demDir:       opts.DEMDir,
		dtmDir:       opts.DTMDir,
		latMin:       latMin,
		latMax:       latMax,
		lonMin:       lonMin,
		lonMax:       lonMax,
		exaggeration: opts.Exaggeration,
		drawContours: opts.DrawContours,
	})
	if err != nil {
		return nil, err
	}
	shadeArticle := imaging.Resize(shadePrint, articleW, 0, imaging.Lanczos)

	osmPrint, err := renderOSMBase(osm, contours, printPr, tmp, "print", lodPrint)
	if err != nil {
		return nil, err
	}
	osmArticle, err := renderOSMBase(osm, contours, articlePr, tmp, "web", lodWeb)
	if err != nil {
		return nil, err
	}
	basePrint := compositeShade(osmPrint, shadePrint, opts.ShadeStrength)
	baseArticle := compositeShade(osmArticle, shadeArticle, opts.ShadeStrength)

	// 6. Output paths. Per-post map assets share the per-post map dir
	//    (router.PostMapPath); this is the "osm" source, "nature" style. Format
	//    is the extension (.svg vector / .png raster / .json georeference);
	//    "-large" is the hi-res raster; "-bg" is the route-free relief base.
	svgURL := router.PostMapPath(post, "-osm-nature.svg")
	pngURL := router.PostMapPath(post, "-osm-nature.png")
	largeURL := router.PostMapPath(post, "-osm-nature-large.png")
	bgURL := router.PostMapPath(post, "-osm-nature-bg.png")
	jsonURL := router.PostMapPath(post, "-osm-nature.json")

	toFile := func(url string) string {
		return filepath.Join(opts.OutputDir, filepath.FromSlash(strings.TrimPrefix(url, "/")))
	}
	svgPath := toFile(svgURL)
	pngPath := toFile(pngURL)
	largePath := toFile(largeURL)
	bgPath := toFile(bgURL)
	jsonPath := toFile(jsonURL)
	if err := os.MkdirAll(filepath.Dir(svgPath), 0o755); err != nil {
		return nil, fmt.Errorf("create output dir: %w", err)
	}

	// 6b. Per-segment slope for the gradient variant (nil if no 10m data covers
	//     the route → we then skip that variant, still producing nature).
	var grads [][]segGradient
	if sampler, sErr := newElevationSampler(latMin, latMax, lonMin, lonMax, opts.DTMDir); sErr == nil {
		grads = routeGradients(post, sampler)
	}

	// 7. Save the route-free relief base for the SVG background, and clone it for
	//    the gradient variant before the solid route is drawn onto the nature
	//    bases (drawing mutates in place).
	if err := imaging.Save(baseArticle, bgPath); err != nil {
		return nil, fmt.Errorf("save relief bg png: %w", err)
	}
	var gradArticle, gradPrint *image.RGBA
	if grads != nil {
		gradArticle = cloneRGBA(baseArticle)
		gradPrint = cloneRGBA(basePrint)
	}

	// Nature variant: solid route.
	drawRouteOnImage(baseArticle, post.Routes, routeColors, articlePr)
	if err := imaging.Save(baseArticle, pngPath); err != nil {
		return nil, fmt.Errorf("save screen png: %w", err)
	}
	drawRouteOnImage(basePrint, post.Routes, routeColors, printPr)
	if err := imaging.Save(basePrint, largePath); err != nil {
		return nil, fmt.Errorf("save large png: %w", err)
	}
	svgFile, err := os.Create(svgPath)
	if err != nil {
		return nil, fmt.Errorf("create svg: %w", err)
	}
	buildSVG(svgFile, post.Routes, routeColors, articlePr, bgURL)
	svgFile.Close()

	// 8. Georeference sidecar (shared by all variants — same extent). Lets a
	//    consumer map lat/lon → pixel (e.g. Panoramio-style photo pins).
	if err := writeGeoRef(jsonPath, zoom, rLatMin, rLatMax, rLonMin, rLonMax, articleW, articleH, printW, printH); err != nil {
		return nil, err
	}

	res := &Result{
		SVGPath:      svgPath,
		PNGPath:      pngPath,
		LargePNGPath: largePath,
		BgPath:       bgPath,
		JSONPath:     jsonPath,
		Zoom:         zoom,
		Width:        articleW,
		Height:       articleH,
		LargeWidth:   printW,
		LargeHeight:  printH,
	}

	// 9. Gradient variant: same relief base, route colored by terrain slope.
	if grads != nil {
		gPngPath := toFile(router.PostMapPath(post, "-osm-gradient.png"))
		gLargePath := toFile(router.PostMapPath(post, "-osm-gradient-large.png"))
		gSvgPath := toFile(router.PostMapPath(post, "-osm-gradient.svg"))

		drawGradientRouteOnImage(gradArticle, grads, articlePr)
		if err := imaging.Save(gradArticle, gPngPath); err != nil {
			return nil, fmt.Errorf("save gradient png: %w", err)
		}
		drawGradientRouteOnImage(gradPrint, grads, printPr)
		if err := imaging.Save(gradPrint, gLargePath); err != nil {
			return nil, fmt.Errorf("save gradient large png: %w", err)
		}
		gf, err := os.Create(gSvgPath)
		if err != nil {
			return nil, fmt.Errorf("create gradient svg: %w", err)
		}
		buildGradientSVG(gf, grads, articlePr, bgURL)
		gf.Close()

		res.GradientSVGPath = gSvgPath
		res.GradientPNGPath = gPngPath
		res.GradientLargePath = gLargePath
	}
	return res, nil
}

// geoRef is the JSON georeference sidecar: rendered lat/lon bounds plus the
// available raster pixel sizes. A consumer maps lat/lon → pixel by linear
// interpolation across bounds (accurate to a few pixels at trip-map scale):
//
//	x = (lon - west) / (east - west) * width
//	y = (north - lat) / (north - south) * height
type geoRef struct {
	Zoom   int `json:"zoom"`
	Bounds struct {
		South float64 `json:"south"`
		West  float64 `json:"west"`
		North float64 `json:"north"`
		East  float64 `json:"east"`
	} `json:"bounds"`
	Sizes struct {
		Screen [2]int `json:"screen"`
		Large  [2]int `json:"large"`
	} `json:"sizes"`
}

// writeGeoRef writes the georeference sidecar for a rendered map.
func writeGeoRef(path string, zoom int, south, north, west, east float64, w, h, lw, lh int) error {
	var g geoRef
	g.Zoom = zoom
	g.Bounds.South, g.Bounds.North = south, north
	g.Bounds.West, g.Bounds.East = west, east
	g.Sizes.Screen = [2]int{w, h}
	g.Sizes.Large = [2]int{lw, lh}
	data, err := json.MarshalIndent(g, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal georef: %w", err)
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return fmt.Errorf("write georef: %w", err)
	}
	return nil
}
