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
	"odkrywajac/internal/index"
	"odkrywajac/internal/loader"
	"odkrywajac/internal/pipeline"
	"odkrywajac/internal/pipeline/nodes"
	"odkrywajac/internal/render"
	"odkrywajac/internal/router"
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

	start := time.Now()

	// 1. Load all configs in parallel
	t0 := time.Now()
	cfg, tags, photoTags, routeColors, stations, pois, err := loader.LoadAllConfigs(ctx.ConfigDir())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading configs: %v\n", err)
		os.Exit(1)
	}
	if ctx.Verbose {
		fmt.Printf("  Configs loaded in %v\n", time.Since(t0))
	}

	// 2. Load areas
	t0 = time.Now()
	areas, err := loader.LoadAreas(ctx.ConfigDir())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading areas: %v\n", err)
		os.Exit(1)
	}
	if ctx.Verbose {
		fmt.Printf("  Areas loaded in %v\n", time.Since(t0))
	}

	// 3. Load posts with routes
	t0 = time.Now()
	posts, err := loader.LoadPosts(ctx.PostsDir(), ctx.RoutesDir())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading posts: %v\n", err)
		os.Exit(1)
	}
	loader.EnrichPostsWithAreaCache(posts, ctx.AreaCacheDir())
	if ctx.Verbose {
		fmt.Printf("  Posts loaded in %v\n", time.Since(t0))
	}

	// 4. Populate photo data from EXIF cache
	t0 = time.Now()
	exifCache := exif.NewCache(ctx.CrystalExifCacheDir())
	loader.PopulatePublishedPhotos(posts, exifCache, photoTags)
	loader.PopulateAllPhotos(posts, ctx.ImagesDir(), exifCache)
	if ctx.Verbose {
		fmt.Printf("  Photos populated in %v\n", time.Since(t0))
	}

	// 5. Build SiteData with indexes
	t0 = time.Now()
	siteData := index.BuildSiteData(posts, tags, photoTags, areas, cfg, routeColors, stations, pois)
	if ctx.Verbose {
		fmt.Printf("  Indexes built in %v\n", time.Since(t0))
	}

	// 6. Create Router and BundleResolver
	siteRouter := router.New(cfg.URL)
	bundleConfigPath := filepath.Join(ctx.BasePath, "go-rewrite", "config", "asset_bundles.yml")
	resolver, err := bundle.NewResolver(bundleConfigPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading asset bundles: %v\n", err)
		os.Exit(1)
	}

	// 7. Copy static assets
	if !ctx.DryRun {
		t0 = time.Now()
		copyNode := nodes.NewCopyAssetsNode()
		if err := copyNode.Run(ctx); err != nil {
			fmt.Fprintf(os.Stderr, "Error copying assets: %v\n", err)
			os.Exit(1)
		}
		if ctx.Verbose {
			fmt.Printf("  Assets copied in %v\n", time.Since(t0))
		}

		// Process images: copy raw + resize to 4 sizes × 2 formats
		t0 = time.Now()
		imgNode := nodes.NewProcessImagesNode(posts)
		if err := imgNode.Run(ctx); err != nil {
			fmt.Fprintf(os.Stderr, "Error processing images: %v\n", err)
			os.Exit(1)
		}
		if ctx.Verbose {
			fmt.Printf("  Images processed in %v\n", time.Since(t0))
		}

		// Precompute asset versions for cache-busting ?v= URLs
		resolver.PrecomputeVersions(ctx.OutputDir())
	}

	// Polygon directory for area show pages
	polygonDir := filepath.Join(ctx.BasePath, "data", "config", "polygons")
	pagesDir := ctx.PagesDir()

	// 8. Generate all views
	t0 = time.Now()
	views := view.GenerateAllViews(siteData, siteRouter, resolver, polygonDir, pagesDir)
	if ctx.Verbose {
		fmt.Printf("  Views generated in %v\n", time.Since(t0))
	}
	fmt.Printf("Views generated: %d\n", len(views))

	if ctx.DryRun {
		fmt.Printf("\nTotal: %v (dry run)\n", time.Since(start))
		return
	}

	// 9. Load or create build manifest
	manifestPath := filepath.Join(ctx.CacheDir(), "build_manifest.json")
	manifest := render.LoadManifest(manifestPath, ctx.Env, ctx.Target)

	// 10. Render all views in parallel
	outputDir := ctx.OutputDir()
	result := render.Render(views, outputDir, manifest, ctx.Workers)

	// 11. Save manifest
	if err := manifest.Save(manifestPath); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: could not save manifest: %v\n", err)
	}

	// 12. Print summary
	fmt.Printf("Rendered: %d (%d workers, %v)\n", result.TotalViews, ctx.Workers, result.Duration)
	fmt.Printf("Written: %d files to %s\n", result.Written, outputDir)
	fmt.Printf("Skipped: %d (unchanged)\n", result.Skipped)
	if result.InputSkipped > 0 {
		fmt.Printf("Input-cached: %d (render skipped)\n", result.InputSkipped)
	}
	fmt.Printf("Manifest: %d entries saved\n", manifest.Len())

	if len(result.Errors) > 0 {
		fmt.Fprintf(os.Stderr, "\nErrors (%d):\n", len(result.Errors))
		for _, err := range result.Errors {
			fmt.Fprintf(os.Stderr, "  %v\n", err)
		}
	}
	if len(result.ValErrors) > 0 {
		fmt.Fprintf(os.Stderr, "\nValidation warnings (%d):\n", len(result.ValErrors))
		for _, e := range result.ValErrors {
			fmt.Fprintf(os.Stderr, "  %s\n", e)
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
