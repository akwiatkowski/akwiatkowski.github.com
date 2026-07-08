package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/draft"
	"odkrywajac/internal/draft/gpx"
	"odkrywajac/internal/draft/strava"
	"odkrywajac/internal/draft/weather"
	"odkrywajac/internal/geodata"
	"odkrywajac/internal/model"
	"odkrywajac/internal/pipeline"
	"odkrywajac/internal/pipeline/nodes"
	"odkrywajac/internal/render"
	"odkrywajac/internal/service/bundle"
	"odkrywajac/internal/service/exif"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/service/spatial"
	"odkrywajac/internal/service/terrain"
	"odkrywajac/internal/validate"
	"odkrywajac/internal/view"
)

func main() {
	buildCmd := flag.NewFlagSet("build", flag.ExitOnError)
	pipelineCmd := flag.NewFlagSet("pipeline", flag.ExitOnError)
	gpxDraftCmd := flag.NewFlagSet("gpx-draft", flag.ExitOnError)
	validateCmd := flag.NewFlagSet("validate", flag.ExitOnError)
	terrainCmd := flag.NewFlagSet("terrain-map", flag.ExitOnError)

	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	switch os.Args[1] {
	case "build":
		ctx := addFlags(buildCmd)
		if err := buildCmd.Parse(os.Args[2:]); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing build flags: %v\n", err)
			os.Exit(1)
		}
		runBuild(ctx)
	case "pipeline":
		ctx := addFlags(pipelineCmd)
		if err := pipelineCmd.Parse(os.Args[2:]); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing pipeline flags: %v\n", err)
			os.Exit(1)
		}
		runPipeline(ctx)
	case "gpx-draft":
		runGpxDraft(gpxDraftCmd)
	case "missing-posts":
		runMissingPosts()
	case "validate":
		ctx := addFlags(validateCmd)
		if err := validateCmd.Parse(os.Args[2:]); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing validate flags: %v\n", err)
			os.Exit(1)
		}
		runValidate(ctx)
	case "terrain-map":
		ctx := addFlags(terrainCmd)
		slug := terrainCmd.String("slug", "", "Post slug to render (exact or suffix match; required)")
		demDir := terrainCmd.String("dem", defaultDEMDir(), "Directory of SRTM .hgt.gz elevation tiles (fallback)")
		dtmDir := terrainCmd.String("dtm", defaultDTMDir(), "Directory of GUGiK 10m .i16.gz elevation tiles")
		demSource := terrainCmd.String("dem-source", "nmt10", "Elevation source: nmt10 (10m) or srtm (30m)")
		osmPBF := terrainCmd.String("osm-pbf", defaultOSMPBF(), "Path to the source .osm.pbf")
		if err := terrainCmd.Parse(os.Args[2:]); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing terrain-map flags: %v\n", err)
			os.Exit(1)
		}
		runTerrainMap(ctx, terrainArgs{slug: *slug, demDir: *demDir, dtmDir: *dtmDir, demSource: *demSource, osmPBF: *osmPBF})
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", os.Args[1])
		printUsage()
		os.Exit(1)
	}
}

func addFlags(fs *flag.FlagSet) *pipeline.Context {
	ctx := &pipeline.Context{
		Workers: runtime.NumCPU(),
	}
	fs.StringVar(&ctx.Env, "env", "dev", "Environment (dev or full)")
	fs.StringVar(&ctx.Target, "target", "local", "Build target/flavor (local or release)")
	fs.StringVar(&ctx.BasePath, "base", ".", "Project root path")
	fs.BoolVar(&ctx.Force, "force", false, "Force rebuild all nodes")
	fs.BoolVar(&ctx.DryRun, "dry-run", false, "Check staleness without executing")
	fs.BoolVar(&ctx.Verbose, "verbose", false, "Verbose output")
	fs.IntVar(&ctx.Workers, "workers", ctx.Workers, "Number of parallel workers")
	return ctx
}

func printUsage() {
	fmt.Fprintln(os.Stderr, "Usage: odkrywajac <command> [flags]")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Commands:")
	fmt.Fprintln(os.Stderr, "  build         Build the static site")
	fmt.Fprintln(os.Stderr, "  pipeline      Run data pipeline")
	fmt.Fprintln(os.Stderr, "  gpx-draft     Generate a draft blog post from a GPX file")
	fmt.Fprintln(os.Stderr, "  missing-posts List Strava activities without blog posts")
	fmt.Fprintln(os.Stderr, "  validate      Sanity-check the rendered output (links, maps, leaked markdown)")
	fmt.Fprintln(os.Stderr, "  terrain-map   Render a shaded-relief route map for one post (overwrites its files)")
}

// defaultDEMDir is the conventional location of the SRTM elevation tiles in
// Olek's input tree, used unless --dem overrides it.
func defaultDEMDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "srtm"
	}
	return filepath.Join(home, "projects", "llm", "input", "srtm")
}

// defaultOSMPBF is the conventional location of the Poland OSM extract.
func defaultOSMPBF() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "poland-latest.osm.pbf"
	}
	return filepath.Join(home, "projects", "llm", "input", "osm", "poland-latest.osm.pbf")
}

// defaultDTMDir is the conventional location of the GUGiK 10m elevation tiles.
func defaultDTMDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "dtm"
	}
	return filepath.Join(home, "projects", "llm", "input", "geo", "dtm")
}

// terrainMapFresh reports whether a post's terrain map is up to date: its
// output SVG exists and is at least as new as the route source file. When the
// route source can't be located, it's considered fresh if the output exists, so
// we don't needlessly re-render every build.
func terrainMapFresh(ctx *pipeline.Context, post *model.Post) bool {
	outSVG := filepath.Join(ctx.OutputDir(), filepath.FromSlash(strings.TrimPrefix(router.PostMapPath(post, "-osm-nature.svg"), "/")))
	outInfo, err := os.Stat(outSVG)
	if err != nil {
		return false // no output yet → render
	}
	if post.CoordsFile == "" {
		return true // output exists, no source to compare → keep it
	}
	srcInfo, err := os.Stat(filepath.Join(ctx.RoutesDir(), post.CoordsFile))
	if err != nil {
		return true
	}
	return !outInfo.ModTime().Before(srcInfo.ModTime())
}

// terrainArgs bundles the terrain-map command inputs.
type terrainArgs struct {
	slug      string
	demDir    string
	dtmDir    string
	demSource string
	osmPBF    string
}

// runTerrainMap renders the shaded-relief route map for a single post and
// overwrites its output files. It is the manual test path for the terrain
// renderer; the same terrain.Render call will later drive a batch pipeline node.
func runTerrainMap(ctx *pipeline.Context, a terrainArgs) {
	if a.slug == "" {
		fmt.Fprintln(os.Stderr, "Error: --slug is required (e.g. --slug 2021-07-18-pagorki-przed-zniwami)")
		os.Exit(1)
	}
	slug := a.slug

	// Route colors come from the shared config; posts carry the route geometry.
	_, _, _, routeColors, _, err := catalog.LoadAllConfigs(ctx.ConfigDir())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading configs: %v\n", err)
		os.Exit(1)
	}
	posts, err := catalog.LoadPosts(ctx.PostsDir(), ctx.RoutesDir(), !ctx.IsRelease())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading posts: %v\n", err)
		os.Exit(1)
	}

	// Match by exact slug first, then by suffix so a short slug (without the
	// date prefix) still resolves to one post.
	var post *model.Post
	for _, candidate := range posts {
		if candidate.Slug == slug {
			post = candidate
			break
		}
	}
	if post == nil {
		for _, candidate := range posts {
			if strings.HasSuffix(candidate.Slug, slug) {
				post = candidate
				break
			}
		}
	}
	if post == nil {
		fmt.Fprintf(os.Stderr, "Error: no post found matching slug %q (loaded %d posts)\n", slug, len(posts))
		os.Exit(1)
	}

	result, err := terrain.Render(post, routeColors, terrain.Options{
		OutputDir:  ctx.OutputDir(),
		DEMSource:  a.demSource,
		DEMDir:     a.demDir,
		DTMDir:     a.dtmDir,
		OSMPBFPath: a.osmPBF,
		Verbose:    ctx.Verbose,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error rendering terrain map for %s: %v\n", post.Slug, err)
		os.Exit(1)
	}

	fmt.Printf("Terrain map rendered for %s (zoom %d):\n", post.Slug, result.Zoom)
	fmt.Printf("  SVG:    %s\n", result.SVGPath)
	fmt.Printf("  PNG:    %s (%dx%d)\n", result.PNGPath, result.Width, result.Height)
	fmt.Printf("  Large:  %s (%dx%d)\n", result.LargePNGPath, result.LargeWidth, result.LargeHeight)
	fmt.Printf("  Bg:     %s\n", result.BgPath)
	fmt.Printf("  Geo:    %s\n", result.JSONPath)

	profilePath, err := terrain.RenderElevationProfile(post, terrain.Options{OutputDir: ctx.OutputDir(), DTMDir: a.dtmDir})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: elevation profile for %s: %v\n", post.Slug, err)
	} else {
		fmt.Printf("  Elev:   %s\n", profilePath)
	}
}

// engineName identifies this renderer in the output dir's .engine marker.
const engineName = "go"

func runBuild(ctx *pipeline.Context) {
	if ctx.Target != "local" && ctx.Target != "release" {
		fmt.Fprintf(os.Stderr, "Invalid --target %q (want local or release)\n", ctx.Target)
		os.Exit(1)
	}
	if ctx.Verbose {
		fmt.Printf("Building with env=%s target=%s workers=%d\n", ctx.Env, ctx.Target, ctx.Workers)
	}
	if ctx.DryRun {
		fmt.Println("Dry run — no changes will be made")
	}

	// Shared results populated by pipeline nodes, consumed by downstream nodes.
	// The pipeline guarantees dependency order, so no races on these variables.
	var (
		cfg         model.SiteConfig
		tags        []model.Tag
		photoTags   []model.PhotoTag
		routeColors map[string]model.RouteColor
		stations    []model.TrainStation
		ideas       []model.Idea
		areas       []*model.Area
		posts       []*model.Post
		polygonDir  string
		siteData    *catalog.SiteData
		siteRouter  *router.Router
		resolver    *bundle.Resolver
		views       []view.Renderable
		renderRes   render.Result
	)

	pipe := pipeline.NewPipeline()

	// --- Data loading (no deps, can conceptually run in parallel) ---

	pipe.Add("loadConfigs", nil, func(ctx *pipeline.Context) error {
		var err error
		cfg, tags, photoTags, routeColors, stations, err = catalog.LoadAllConfigs(ctx.ConfigDir())
		return err
	})

	pipe.Add("generateAreaConfigs", nil, func(ctx *pipeline.Context) error {
		_, err := geodata.GenerateAreaConfigs(ctx.ExternalDir(), ctx.GlobalCacheDir(), ctx.Force)
		return err
	})

	pipe.Add("loadPosts", nil, func(ctx *pipeline.Context) error {
		var err error
		// Local preview builds keep hidden drafts so they can be viewed at
		// localhost; release builds exclude them from the published site.
		posts, err = catalog.LoadPosts(ctx.PostsDir(), ctx.RoutesDir(), !ctx.IsRelease())
		if err != nil {
			return err
		}
		// Try Go-generated cache first, fall back to Crystal cache
		catalog.EnrichPostsWithAreaCache(posts, ctx.RouteCoverageDir())
		catalog.EnrichPostsWithAreaCache(posts, ctx.AreaCacheDir())
		return nil
	})

	pipe.Add("loadIdeas", nil, func(ctx *pipeline.Context) error {
		var err error
		ideas, err = catalog.LoadIdeas(ctx.IdeasDir())
		return err
	})

	pipe.Add("loadBundles", nil, func(ctx *pipeline.Context) error {
		// Single source of truth shared with Crystal (was a data/config fork).
		bundlePath := filepath.Join(ctx.ConfigDir(), "asset_bundles.yml")
		var err error
		resolver, err = bundle.NewResolver(bundlePath)
		return err
	})

	// --- Depends on generateAreaConfigs ---

	pipe.Add("loadAreas", []string{"generateAreaConfigs"}, func(ctx *pipeline.Context) error {
		areasDir := filepath.Join(ctx.GlobalCacheDir(), "areas")
		var err error
		areas, err = catalog.LoadAreas(areasDir)
		return err
	})

	// --- Depends on loadPosts + loadConfigs ---

	pipe.Add("loadPhotos", []string{"loadPosts", "loadConfigs"}, func(ctx *pipeline.Context) error {
		exifCache := exif.NewCache(ctx.ExifCacheDir())
		catalog.PopulatePublishedPhotos(posts, exifCache, photoTags, ctx.ImagesDir())
		catalog.PopulateAllPhotos(posts, ctx.ImagesDir(), exifCache)
		return nil
	})

	// --- Spatial matching: route→area distances and photo→area assignment ---

	pipe.Add("spatialMatching", []string{"loadAreas", "loadPhotos"}, func(ctx *pipeline.Context) error {
		if ctx.DryRun {
			return nil
		}

		routeCoverageDir := ctx.RouteCoverageDir()
		areaPhotosDir := ctx.AreaPhotosDir()

		// Check if all spatial caches are fresh — if so, skip the expensive
		// 93MB YAML + GEOS geometry load entirely.
		if !ctx.Force && isSpatialFresh(posts, routeCoverageDir, areaPhotosDir, ctx.RoutesDir()) {
			if ctx.Verbose {
				fmt.Println("Spatial matching: all caches fresh, skipping")
			}
			return nil
		}

		matcher, err := spatial.NewMatcher(ctx.ExternalDir(), spatial.LoadExternalAreas)
		if err != nil {
			return fmt.Errorf("create spatial matcher: %w", err)
		}
		defer matcher.Close()

		// Phase 1: Route coverage (areas_for_post)
		routesGenerated := 0
		for _, post := range posts {
			if len(post.Routes) == 0 {
				continue
			}
			// Build route file paths for proper mtime comparison
			var routePaths []string
			if post.CoordsFile != "" {
				routePaths = []string{filepath.Join(ctx.RoutesDir(), post.CoordsFile)}
			}
			if !ctx.Force && !spatial.IsRouteCoverageStale(routeCoverageDir, post.Slug, routePaths) {
				continue
			}
			result := matcher.MatchRoute(post.Routes[0].Segments, post.Routes[0].Type)
			if err := spatial.WriteRouteCoverage(routeCoverageDir, post.Slug, result); err != nil {
				return fmt.Errorf("write route coverage for %s: %w", post.Slug, err)
			}
			routesGenerated++
		}
		if routesGenerated > 0 {
			fmt.Printf("Route coverage: %d posts generated\n", routesGenerated)
		}

		// Phase 2: Photo→area assignment
		assignments := make(map[spatial.AreaKey][]spatial.PhotoRef)
		photosMatched := 0
		for _, post := range posts {
			for _, photo := range post.AllPhotos {
				if !photo.HasGPS() {
					continue
				}
				pointResult := matcher.MatchPoint(*photo.Exif.Lat, *photo.Exif.Lon)
				ref := spatial.PhotoRef{Filename: photo.ImageFilename, PostSlug: post.Slug}
				addPhotoRefs(assignments, "towns", pointResult.Towns, ref)
				addPhotoRefs(assignments, "counties", pointResult.Counties, ref)
				addPhotoRefs(assignments, "voivodeships", pointResult.Voivodeships, ref)
				addPhotoRefs(assignments, "meso_regions", pointResult.MesoRegions, ref)
				addPhotoRefs(assignments, "macro_regions", pointResult.MacroRegions, ref)
				photosMatched++
			}
		}
		if err := spatial.WritePhotosInArea(areaPhotosDir, assignments); err != nil {
			return fmt.Errorf("write photos in area: %w", err)
		}
		if photosMatched > 0 {
			fmt.Printf("Photo assignments: %d photos → %d area files\n", photosMatched, len(assignments))
		}

		// Re-enrich posts with freshly generated route coverage
		catalog.EnrichPostsWithAreaCache(posts, routeCoverageDir)

		return nil
	})

	// --- Depends on loadAreas + loadPosts + spatialMatching ---

	pipe.Add("generatePolygons", []string{"loadAreas", "loadPosts", "spatialMatching"}, func(ctx *pipeline.Context) error {
		polygonDir = filepath.Join(ctx.GlobalCacheDir(), "polygons")
		// Generate polygons from Go route coverage cache (primary source)
		_, err := geodata.Generate(
			ctx.ExternalDir(), polygonDir, ctx.RouteCoverageDir(),
			posts, areas, geodata.DefaultTolerance, ctx.Force,
		)
		if err != nil {
			return err
		}
		// Also collect from Crystal cache (never force, just fill gaps)
		_, err = geodata.Generate(
			ctx.ExternalDir(), polygonDir, ctx.AreaCacheDir(),
			posts, areas, geodata.DefaultTolerance, false,
		)
		return err
	})

	// --- Build indexes from all loaded data ---

	pipe.Add("buildSiteData", []string{"loadConfigs", "loadAreas", "loadPhotos", "loadIdeas"}, func(_ *pipeline.Context) error {
		siteData = catalog.BuildSiteData(posts, tags, photoTags, areas, cfg, routeColors, stations, ideas)
		return nil
	})

	pipe.Add("createRouter", []string{"loadConfigs"}, func(_ *pipeline.Context) error {
		siteRouter = router.New(cfg.URL)
		return nil
	})

	// --- Asset pipeline (skipped in dry-run) ---

	pipe.Add("copyAssets", nil, func(ctx *pipeline.Context) error {
		if ctx.DryRun {
			return nil
		}
		return nodes.NewCopyAssetsNode().Run(ctx)
	})

	pipe.Add("processImages", []string{"loadPosts"}, func(ctx *pipeline.Context) error {
		if ctx.DryRun {
			return nil
		}
		return nodes.NewProcessImagesNode(posts).Run(ctx)
	})

	pipe.Add("precomputeVersions", []string{"loadBundles", "copyAssets", "processImages"}, func(ctx *pipeline.Context) error {
		if ctx.DryRun {
			return nil
		}
		resolver.PrecomputeVersions(ctx.OutputDir())
		return nil
	})

	// --- View generation and rendering ---

	pipe.Add("generateViews", []string{"buildSiteData", "createRouter", "copyAssets", "processImages", "precomputeVersions", "generatePolygons"}, func(ctx *pipeline.Context) error {
		// polygonDir = generated cache (area show pages); config polygons are
		// the complete committed set (all voivodeships + visited counties)
		// used by the homepage coverage map.
		polygonConfigDir := filepath.Join(ctx.ConfigDir(), "polygons")
		views = view.GenerateAllViews(siteData, siteRouter, resolver, polygonDir, polygonConfigDir, ctx.PagesDir(), ctx.IsRelease())
		fmt.Printf("Views generated: %d\n", len(views))
		return nil
	})

	pipe.Add("renderViews", []string{"generateViews"}, func(ctx *pipeline.Context) error {
		if ctx.DryRun {
			return nil
		}
		// If another engine last wrote this output dir, the per-engine manifest
		// is not a valid staleness map for it — force a full render so the dir
		// ends up wholly owned by this engine. (Bytes may be rewritten identically.)
		force := ctx.Force || engineMarkerMismatch(ctx)

		manifestPath := ctx.ManifestPath()
		manifest := render.LoadManifest(manifestPath, ctx.Env, ctx.Target)
		if force {
			manifest = render.NewManifest(ctx.Env, ctx.Target)
		}
		renderRes = render.Render(views, ctx.OutputDir(), manifest, ctx.Workers)
		if err := manifest.Save(manifestPath); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: could not save manifest: %v\n", err)
		}
		if err := writeEngineMarker(ctx); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: could not write engine marker: %v\n", err)
		}
		return nil
	})

	// Terrain maps run right after the SVG maps, over the same posts. They shell
	// out to GDAL/osmium/rsvg and are slow, so each post is rendered only when
	// its route changed (or --force); the whole step is skipped with a message
	// if the geo toolchain or the OSM/DEM input data isn't present.
	pipe.Add("renderTerrainMaps", []string{"renderViews", "loadPosts", "loadConfigs"}, func(ctx *pipeline.Context) error {
		if ctx.DryRun {
			return nil
		}
		opts := terrain.Options{
			OutputDir:  ctx.OutputDir(),
			OSMPBFPath: defaultOSMPBF(),
			DEMDir:     defaultDEMDir(),
			DTMDir:     defaultDTMDir(),
			Verbose:    ctx.Verbose,
		}
		if err := terrain.CheckAvailable(opts); err != nil {
			fmt.Printf("Terrain maps: skipped (%v)\n", err)
			return nil
		}
		rendered, fresh, failed := 0, 0, 0
		for _, post := range posts {
			if !post.HasRoutes() {
				continue
			}
			if !ctx.Force && terrainMapFresh(ctx, post) {
				fresh++
				continue
			}
			if _, err := terrain.Render(post, routeColors, opts); err != nil {
				fmt.Fprintf(os.Stderr, "  terrain %s: %v\n", post.Slug, err)
				failed++
				continue
			}
			if _, err := terrain.RenderElevationProfile(post, opts); err != nil {
				fmt.Fprintf(os.Stderr, "  elevation %s: %v\n", post.Slug, err)
			}
			rendered++
		}
		fmt.Printf("Terrain maps: %d rendered, %d fresh, %d failed\n", rendered, fresh, failed)
		return nil
	})

	// --- Execute ---

	start := time.Now()
	if err := pipe.Run(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "Build failed: %v\n", err)
		os.Exit(1)
	}

	// --- Summary ---

	if ctx.DryRun {
		fmt.Printf("\nTotal: %v (dry run)\n", time.Since(start))
		return
	}

	fmt.Printf("Rendered: %d (%d workers, %v)\n", renderRes.TotalViews, ctx.Workers, renderRes.Duration)
	fmt.Printf("Written: %d files to %s\n", renderRes.Written, ctx.OutputDir())
	fmt.Printf("Skipped: %d (unchanged)\n", renderRes.Skipped)
	if renderRes.InputSkipped > 0 {
		fmt.Printf("Input-cached: %d (render skipped)\n", renderRes.InputSkipped)
	}

	if len(renderRes.Errors) > 0 {
		fmt.Fprintf(os.Stderr, "\nErrors (%d):\n", len(renderRes.Errors))
		for _, err := range renderRes.Errors {
			fmt.Fprintf(os.Stderr, "  %v\n", err)
		}
	}
	if len(renderRes.ValErrors) > 0 {
		fmt.Fprintf(os.Stderr, "\nValidation warnings (%d):\n", len(renderRes.ValErrors))
		for _, valErr := range renderRes.ValErrors {
			fmt.Fprintf(os.Stderr, "  %s\n", valErr)
		}
	}

	fmt.Printf("\nTotal: %v\n", time.Since(start))
}

// engineMarkerMismatch reports whether OutputDir was last written by a different
// engine (or a legacy build with no marker), which invalidates our per-engine
// manifest for that dir. A missing marker on a non-empty dir counts as a
// mismatch so the first Go render after a Crystal render rewrites everything.
func engineMarkerMismatch(ctx *pipeline.Context) bool {
	data, err := os.ReadFile(ctx.EngineMarkerPath())
	if err != nil {
		// No marker: mismatch only if the dir already has content (e.g. Crystal
		// output). A fresh/empty dir is not a mismatch.
		if entries, derr := os.ReadDir(ctx.OutputDir()); derr == nil && len(entries) > 0 {
			return true
		}
		return false
	}
	return strings.TrimSpace(string(data)) != engineName
}

// writeEngineMarker stamps OutputDir with this engine's name so a later render
// by the other engine knows to force a full rewrite.
func writeEngineMarker(ctx *pipeline.Context) error {
	if err := os.MkdirAll(ctx.OutputDir(), 0o755); err != nil {
		return err
	}
	return os.WriteFile(ctx.EngineMarkerPath(), []byte(engineName+"\n"), 0o644)
}

func runPipeline(ctx *pipeline.Context) {
	if ctx.Verbose {
		fmt.Printf("Pipeline with env=%s target=%s workers=%d\n", ctx.Env, ctx.Target, ctx.Workers)
	}
	if ctx.DryRun {
		fmt.Println("Dry run — no changes will be made")
	}
	fmt.Println("Pipeline: no nodes registered yet")
}

func runGpxDraft(fs *flag.FlagSet) {
	var (
		gpxFile       = fs.String("gpx", "", "Path to GPX file")
		activityID    = fs.Int64("id", 0, "Strava activity ID (alternative to -gpx)")
		postsDir      = fs.String("posts-dir", "", "Target posts directory (default: ../env/full/data/posts/YYYY from GPX date)")
		title         = fs.String("title", "", "Post title (default: activity name or required with -gpx)")
		subtitle      = fs.String("subtitle", "", "Post subtitle")
		author        = fs.String("author", "Aleksander Kwiatkowski", "Post author")
		category      = fs.String("category", "trip", "Post category")
		tags          = fs.String("tags", "bicycle,todo", "Comma-separated tags")
		imageFilename = fs.String("image", "", "Header image filename")
		weatherFlag   = fs.Bool("weather", true, "Fetch weather data from Open-Meteo")
		dryRun        = fs.Bool("dry-run", false, "Print draft to stdout without writing")
	)

	if err := fs.Parse(os.Args[2:]); err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing gpx-draft flags: %v\n", err)
		os.Exit(1)
	}

	var stats *gpx.RideStats
	var activity *strava.Activity

	switch {
	case *activityID != 0:
		// Load from Strava activity ID
		stravaBase := os.Getenv("LLM_CYCLING_STRAVA")
		if stravaBase == "" {
			fmt.Fprintln(os.Stderr, "Error: LLM_CYCLING_STRAVA env var not set")
			os.Exit(1)
		}

		activityPath := filepath.Join(stravaBase, "activities", fmt.Sprintf("%d.json", *activityID))
		data, err := os.ReadFile(activityPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading activity %d: %v\n", *activityID, err)
			os.Exit(1)
		}

		activity = &strava.Activity{}
		if err := json.Unmarshal(data, activity); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing activity %d: %v\n", *activityID, err)
			os.Exit(1)
		}

		stats = activityToStats(activity)
		fmt.Printf("Loaded activity %d: %.1f km, %.1f h, +%.0f m elevation\n",
			activity.ID, stats.DistanceKm, stats.Duration.Hours(), stats.ElevationGain)

		if *title == "" {
			*title = activity.Name
		}
	case *gpxFile != "":
		// Parse GPX file
		var err error
		stats, err = gpx.ParseFile(*gpxFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing GPX: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("GPX parsed: %.1f km, %.1f h, +%.0f m elevation\n",
			stats.DistanceKm, stats.Duration.Hours(), stats.ElevationGain)
	default:
		fmt.Fprintln(os.Stderr, "Error: either -gpx or -id flag is required")
		fmt.Fprintln(os.Stderr, "Usage:")
		fmt.Fprintln(os.Stderr, "  odkrywajac gpx-draft -gpx <file.gpx> -title \"My Ride\"")
		fmt.Fprintln(os.Stderr, "  odkrywajac gpx-draft -id <activity-id> [-title \"My Ride\"]")
		os.Exit(1)
	}

	if *title == "" {
		fmt.Fprintln(os.Stderr, "Error: -title flag is required")
		os.Exit(1)
	}

	// Determine posts directory. Posts live under env/full/data/posts/<year> —
	// the repo-root data/ dir holds configs and sources, never posts.
	targetPostsDir := *postsDir
	if targetPostsDir == "" {
		year := stats.StartTime.Year()
		targetPostsDir = filepath.Join("..", "env", "full", "data", "posts", fmt.Sprintf("%d", year))
	}

	// Fetch weather if requested
	var weatherData *weather.Data
	if *weatherFlag {
		client := weather.NewClient()
		var lat, lon float64
		if activity != nil && len(activity.StartLatLng) == 2 {
			lat = activity.StartLatLng[0]
			lon = activity.StartLatLng[1]
		} else {
			lat = stats.StartPoint.Lat
			lon = stats.StartPoint.Lon
		}
		w, err := client.Fetch(lat, lon, stats.StartTime)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Warning: could not fetch weather: %v\n", err)
		} else {
			weatherData = w
			fmt.Printf("Weather: %.1f°C, %d%% clouds, %.1f km/h wind\n",
				w.Temperature, w.CloudCover, w.WindSpeed)
		}
	}

	// Generate draft
	gen := &draft.Generator{PostsDir: targetPostsDir}
	opts := draft.Options{
		Title:         *title,
		Subtitle:      *subtitle,
		Author:        *author,
		Category:      *category,
		Tags:          strings.Split(*tags, ","),
		ImageFilename: *imageFilename,
		Weather:       weatherData,
		DryRun:        *dryRun,
	}

	outputPath, err := gen.Generate(stats, opts)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error generating draft: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Draft written to: %s\n", outputPath)
}

// activityToStats converts a Strava Activity to gpx.RideStats for draft generation.
func activityToStats(a *strava.Activity) *gpx.RideStats {
	return &gpx.RideStats{
		StartTime:     a.StartDate,
		EndTime:       a.StartDate.Add(time.Duration(a.MovingTime) * time.Second),
		Duration:      time.Duration(a.MovingTime) * time.Second,
		DistanceKm:    a.DistanceKm(),
		ElevationGain: a.TotalElevationGain,
		ElevationLoss: 0, // Not available in Strava summary
		MinElevation:  0,
		MaxElevation:  0,
		ActivityType:  stravaTypeToCoordsType(a.Type, a.SportType),
	}
}

// stravaTypeToCoordsType maps Strava activity types to blog coords_type values.
func stravaTypeToCoordsType(activityType, sportType string) string {
	t := strings.ToLower(activityType)
	st := strings.ToLower(sportType)

	if t == "ebikeride" || st == "ebikeride" {
		return "e-bike"
	}
	if t == "ride" || st == "gravelride" || st == "mountainbikeride" ||
		st == "roadride" || st == "cyclocross" {
		return "bicycle"
	}
	if t == "hike" || t == "walk" {
		return "hike"
	}
	return t
}

func runMissingPosts() {
	// Get Strava activities directory from env var
	stravaBase := os.Getenv("LLM_CYCLING_STRAVA")
	if stravaBase == "" {
		fmt.Fprintln(os.Stderr, "Error: LLM_CYCLING_STRAVA env var not set")
		fmt.Fprintln(os.Stderr, "Hint: source your shell config or set it manually:")
		fmt.Fprintln(os.Stderr, "  export LLM_CYCLING_STRAVA=$HOME/projects/llm/input/cycling/strava")
		os.Exit(1)
	}

	activitiesDir := filepath.Join(stravaBase, "activities")

	// Load all Strava activities
	activities, err := strava.LoadActivities(activitiesDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading activities: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Loaded %d activities from %s\n", len(activities), activitiesDir)

	// Filter by distance
	var longActivities []*strava.Activity
	for _, a := range activities {
		if a.IsLongEnough() {
			longActivities = append(longActivities, a)
		}
	}
	fmt.Printf("After distance filter (bike>=25km, hike>=2km): %d activities\n", len(longActivities))

	// Drop activities Olek explicitly marked as never getting a post (commutes,
	// tests, duplicates). The skip-list lives next to the strava dir, outside the
	// blog repo — maintained by the trip-draft-post skill.
	ignoredPath := filepath.Join(stravaBase, "..", "ignored_activities.yml")
	ignoredIDs, err := strava.LoadIgnoredIDs(ignoredPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: could not load ignore list: %v\n", err)
	} else if len(ignoredIDs) > 0 {
		var kept []*strava.Activity
		for _, a := range longActivities {
			if !ignoredIDs[a.ID] {
				kept = append(kept, a)
			}
		}
		fmt.Printf("After ignore list (%s): %d activities (%d ignored)\n",
			ignoredPath, len(kept), len(longActivities)-len(kept))
		longActivities = kept
	}

	// Build set of activity IDs from posts. Hidden drafts count too — a
	// drafted activity is no longer "missing", so use LoadAllPosts.
	postsDir := filepath.Join("..", "env", "full", "data", "posts")
	posts, err := catalog.LoadAllPosts(postsDir, "")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: could not load posts: %v\n", err)
		os.Exit(1)
	}

	postStravaIDs := make(map[int64]bool)
	for _, post := range posts {
		for _, s := range post.Strava {
			if id, ok := strava.ExtractActivityID(s); ok {
				postStravaIDs[id] = true
			}
		}
	}
	fmt.Printf("Found %d unique Strava IDs in %d blog posts\n", len(postStravaIDs), len(posts))

	// Find missing activities
	var missing []*strava.Activity
	for _, a := range longActivities {
		if !postStravaIDs[a.ID] {
			missing = append(missing, a)
		}
	}

	if len(missing) == 0 {
		fmt.Println("\n✓ All activities have blog posts!")
		return
	}

	// Sort by date (newest first)
	for i := 0; i < len(missing)-1; i++ {
		for j := i + 1; j < len(missing); j++ {
			if missing[i].StartDate.Before(missing[j].StartDate) {
				missing[i], missing[j] = missing[j], missing[i]
			}
		}
	}

	fmt.Printf("\n═══ Missing blog posts: %d activities ═══\n\n", len(missing))
	fmt.Printf("%-12s %-10s %-8s %-10s %-6s %s\n", "Date", "Distance", "Time", "ID", "Type", "Name")
	fmt.Println(strings.Repeat("─", 90))

	for _, a := range missing {
		dateStr := a.StartDateLocal.Format("2006-01-02")
		activityType := a.Type
		if a.SportType != "" && a.SportType != a.Type {
			activityType = a.SportType
		}
		fmt.Printf("%-12s %-10.1f %-8.1f %-10d %-6s %s\n",
			dateStr,
			a.DistanceKm(),
			a.DurationHours(),
			a.ID,
			activityType,
			a.Name,
		)
	}

	fmt.Println()
	fmt.Println("Generate draft commands:")
	for _, a := range missing {
		fmt.Printf("  make gpx-draft ID=%d TITLE=%q\n", a.ID, a.Name)
	}
}

// isSpatialFresh checks whether all spatial matching caches are up-to-date,
// allowing the expensive GEOS/YAML loading to be skipped entirely.
// Returns true if every post with a route has a cache file, and the photos_in_area
// directory exists and is non-empty.
func isSpatialFresh(posts []*model.Post, routeCoverageDir, areaPhotosDir, routesDir string) bool {
	// Check that every post with routes has a fresh cache file
	for _, post := range posts {
		if len(post.Routes) == 0 {
			continue
		}
		var routePaths []string
		if post.CoordsFile != "" {
			routePaths = []string{filepath.Join(routesDir, post.CoordsFile)}
		}
		if spatial.IsRouteCoverageStale(routeCoverageDir, post.Slug, routePaths) {
			return false
		}
	}

	// Check that photo assignments directory exists and has content
	entries, err := os.ReadDir(areaPhotosDir)
	if err != nil || len(entries) == 0 {
		return false
	}

	return true
}

// addPhotoRefs accumulates photo references into the assignments map
// for each area that matched a point-in-polygon test.
func addPhotoRefs(assignments map[spatial.AreaKey][]spatial.PhotoRef, typePlural string, refs []spatial.AreaRef, photo spatial.PhotoRef) {
	for _, ref := range refs {
		key := spatial.AreaKey{TypePlural: typePlural, Slug: ref.Slug}
		assignments[key] = append(assignments[key], photo)
	}
}

// runValidate sanity-checks the already-rendered output directory: broken
// internal links, posts with a route but no rendered map, and leaked markdown
// link syntax. It exits non-zero when any issue is found so it can gate CI.
func runValidate(ctx *pipeline.Context) {
	posts, err := catalog.LoadPosts(ctx.PostsDir(), ctx.RoutesDir(), !ctx.IsRelease())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading posts: %v\n", err)
		os.Exit(1)
	}

	// Posts with a route must render a map. The URL scheme mirrors
	// router.PostURL: /YYYY/MM/DD-<slug-without-date-prefix>.html.
	routeMapURLs := make(map[string]bool)
	for _, post := range posts {
		if post.HasRoutes() {
			url := fmt.Sprintf("/%d/%02d/%s.html", post.Date.Year(), post.Date.Month(), post.Slug[8:])
			routeMapURLs[url] = true
		}
	}

	outputRoot := ctx.OutputDir()
	issues, err := validate.Run(outputRoot, routeMapURLs)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error validating %s: %v\n", outputRoot, err)
		os.Exit(1)
	}

	if len(issues) == 0 {
		fmt.Printf("✓ %s: no validation issues (%d route posts checked)\n", outputRoot, len(routeMapURLs))
		return
	}

	counts := make(map[string]int)
	for _, issue := range issues {
		counts[issue.Kind]++
		fmt.Fprintln(os.Stderr, issue)
	}
	fmt.Fprintf(os.Stderr, "\n%d validation issue(s): ", len(issues))
	for kind, n := range counts {
		fmt.Fprintf(os.Stderr, "%s=%d ", kind, n)
	}
	fmt.Fprintln(os.Stderr)
	os.Exit(1)
}
