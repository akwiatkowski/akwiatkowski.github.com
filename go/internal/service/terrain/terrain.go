package terrain

import (
	"fmt"
	"math"
	"os"
	"path/filepath"

	"github.com/disintegration/imaging"

	"odkrywajac/internal/model"
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
	outputSubdir         = "mapy-terenowe"
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
	PrintPNGPath string
	ReliefPath   string
	Zoom         int
	Width        int
	Height       int
	PrintWidth   int
	PrintHeight  int
}

// Render produces a shaded-relief route map for a single post and writes the
// SVG, article PNG, print PNG, and the relief background PNG (referenced by the
// SVG) under <OutputDir>/mapy-terenowe/<year>/. Existing files are overwritten.
//
// It is the single entry point shared by the `terrain-map` test command and, in
// future, a cold-render-path pipeline node — keep all rendering logic here so
// enabling the batch path is just a matter of calling Render in a loop.
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

	// 5. Build the base map at print resolution: OSM "normal" map shaded by the
	//    hillshade. Both are rendered to the exact same extent/pixel grid so they
	//    align; the article/web variants are downscaled from this.
	tmp, err := os.MkdirTemp("", "terrain-render-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(tmp)

	printPr := projector{zoom: zoom, minPX: bounds.MinPX, minPY: bounds.MinPY, cropW: cropW, cropH: cropH, width: float64(printW), height: float64(printH)}

	osm, err := loadOSM(latMin, latMax, lonMin, lonMax, opts.OSMPBFPath, opts.OSMMarginDeg, opts.OSMCacheDir)
	if err != nil {
		return nil, err
	}
	osmImg, err := renderOSMBase(osm, printPr, tmp)
	if err != nil {
		return nil, err
	}
	shade, err := renderHillshade(demParams{
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
	})
	if err != nil {
		return nil, err
	}
	base := compositeShade(osmImg, shade, opts.ShadeStrength)

	// 6. Output paths.
	year := post.Date.Year()
	dir := filepath.Join(opts.OutputDir, outputSubdir, fmt.Sprintf("%d", year))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, fmt.Errorf("create output dir: %w", err)
	}
	svgPath := filepath.Join(dir, post.Slug+".svg")
	pngPath := filepath.Join(dir, post.Slug+".png")
	printPath := filepath.Join(dir, post.Slug+"-print.png")
	reliefPath := filepath.Join(dir, post.Slug+"-relief.png")
	reliefURL := fmt.Sprintf("/%s/%d/%s-relief.png", outputSubdir, year, post.Slug)

	// 7. Save the relief background (route-free) for the SVG, then draw the route
	//    onto the base for the raster outputs.
	reliefWeb := imaging.Resize(base, articleW, 0, imaging.Lanczos)
	if err := imaging.Save(reliefWeb, reliefPath); err != nil {
		return nil, fmt.Errorf("save relief png: %w", err)
	}

	drawRouteOnImage(base, post.Routes, routeColors, printPr)

	if err := imaging.Save(base, printPath); err != nil {
		return nil, fmt.Errorf("save print png: %w", err)
	}
	articleImg := imaging.Resize(base, articleW, 0, imaging.Lanczos)
	if err := imaging.Save(articleImg, pngPath); err != nil {
		return nil, fmt.Errorf("save article png: %w", err)
	}

	// 8. SVG: relief background + crisp vector route at article dimensions.
	articlePr := projector{zoom: zoom, minPX: bounds.MinPX, minPY: bounds.MinPY, cropW: cropW, cropH: cropH, width: float64(articleW), height: float64(articleH)}
	svgFile, err := os.Create(svgPath)
	if err != nil {
		return nil, fmt.Errorf("create svg: %w", err)
	}
	defer svgFile.Close()
	buildSVG(svgFile, post.Routes, routeColors, articlePr, reliefURL)

	return &Result{
		SVGPath:      svgPath,
		PNGPath:      pngPath,
		PrintPNGPath: printPath,
		ReliefPath:   reliefPath,
		Zoom:         zoom,
		Width:        articleW,
		Height:       articleH,
		PrintWidth:   printW,
		PrintHeight:  printH,
	}, nil
}
