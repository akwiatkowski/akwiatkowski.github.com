package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/exif"
	"odkrywajac/internal/geodata"
	"odkrywajac/internal/index"
	"odkrywajac/internal/loader"
	"odkrywajac/internal/model"
	"odkrywajac/internal/pipeline"
	"odkrywajac/internal/pipeline/nodes"
	"odkrywajac/internal/render"
	"odkrywajac/internal/router"
	"odkrywajac/internal/spatial"
	"odkrywajac/internal/view"
)

func main() {
	buildCmd := flag.NewFlagSet("build", flag.ExitOnError)
	pipelineCmd := flag.NewFlagSet("pipeline", flag.ExitOnError)

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
	fs.StringVar(&ctx.Target, "target", "go", "Build target directory name")
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
	fmt.Fprintln(os.Stderr, "  build      Build the static site")
	fmt.Fprintln(os.Stderr, "  pipeline   Run data pipeline")
}

func runBuild(ctx *pipeline.Context) {
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
		siteData    *index.SiteData
		siteRouter  *router.Router
		resolver    *bundle.Resolver
		views       []view.Renderable
		renderRes   render.Result
	)

	pipe := pipeline.NewPipeline()

	// --- Data loading (no deps, can conceptually run in parallel) ---

	pipe.Add("loadConfigs", nil, func(ctx *pipeline.Context) error {
		var err error
		cfg, tags, photoTags, routeColors, stations, err = loader.LoadAllConfigs(ctx.ConfigDir())
		return err
	})

	pipe.Add("generateAreaConfigs", nil, func(ctx *pipeline.Context) error {
		_, err := geodata.GenerateAreaConfigs(ctx.ExternalDir(), ctx.GlobalCacheDir(), ctx.Force)
		return err
	})

	pipe.Add("loadPosts", nil, func(ctx *pipeline.Context) error {
		var err error
		posts, err = loader.LoadPosts(ctx.PostsDir(), ctx.RoutesDir())
		if err != nil {
			return err
		}
		// Try Go-generated cache first, fall back to Crystal cache
		loader.EnrichPostsWithAreaCache(posts, ctx.RouteCoverageDir())
		loader.EnrichPostsWithAreaCache(posts, ctx.AreaCacheDir())
		return nil
	})

	pipe.Add("loadIdeas", nil, func(ctx *pipeline.Context) error {
		var err error
		ideas, err = loader.LoadIdeas(ctx.IdeasDir())
		return err
	})

	pipe.Add("loadBundles", nil, func(ctx *pipeline.Context) error {
		bundlePath := filepath.Join(ctx.BasePath, "go-rewrite", "config", "asset_bundles.yml")
		var err error
		resolver, err = bundle.NewResolver(bundlePath)
		return err
	})

	// --- Depends on generateAreaConfigs ---

	pipe.Add("loadAreas", []string{"generateAreaConfigs"}, func(ctx *pipeline.Context) error {
		areasDir := filepath.Join(ctx.GlobalCacheDir(), "areas")
		var err error
		areas, err = loader.LoadAreas(areasDir)
		return err
	})

	// --- Depends on loadPosts + loadConfigs ---

	pipe.Add("loadPhotos", []string{"loadPosts", "loadConfigs"}, func(ctx *pipeline.Context) error {
		exifCache := exif.NewCache(ctx.ExifCacheDir())
		loader.PopulatePublishedPhotos(posts, exifCache, photoTags, ctx.ImagesDir())
		loader.PopulateAllPhotos(posts, ctx.ImagesDir(), exifCache)
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
		loader.EnrichPostsWithAreaCache(posts, routeCoverageDir)

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
		siteData = index.BuildSiteData(posts, tags, photoTags, areas, cfg, routeColors, stations, ideas)
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
		views = view.GenerateAllViews(siteData, siteRouter, resolver, polygonDir, ctx.PagesDir())
		fmt.Printf("Views generated: %d\n", len(views))
		return nil
	})

	pipe.Add("renderViews", []string{"generateViews"}, func(ctx *pipeline.Context) error {
		if ctx.DryRun {
			return nil
		}
		manifestPath := filepath.Join(ctx.CacheDir(), "build_manifest.json")
		manifest := render.LoadManifest(manifestPath, ctx.Env, ctx.Target)
		renderRes = render.Render(views, ctx.OutputDir(), manifest, ctx.Workers)
		if err := manifest.Save(manifestPath); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: could not save manifest: %v\n", err)
		}
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

func runPipeline(ctx *pipeline.Context) {
	if ctx.Verbose {
		fmt.Printf("Pipeline with env=%s target=%s workers=%d\n", ctx.Env, ctx.Target, ctx.Workers)
	}
	if ctx.DryRun {
		fmt.Println("Dry run — no changes will be made")
	}
	fmt.Println("Pipeline: no nodes registered yet")
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
