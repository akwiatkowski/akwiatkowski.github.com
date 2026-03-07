package main

import (
	"flag"
	"fmt"
	"os"
	"runtime"
	"time"

	"odkrywajac/internal/index"
	"odkrywajac/internal/loader"
	"odkrywajac/internal/pipeline"
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
		buildCmd.Parse(os.Args[2:])
		runBuild(ctx)
	case "pipeline":
		ctx := addFlags(pipelineCmd)
		pipelineCmd.Parse(os.Args[2:])
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
	if ctx.Verbose {
		fmt.Printf("  Posts loaded in %v\n", time.Since(t0))
	}

	// 4. Build SiteData with indexes
	t0 = time.Now()
	sd := index.BuildSiteData(posts, tags, photoTags, areas, cfg, routeColors, stations, pois)
	if ctx.Verbose {
		fmt.Printf("  Indexes built in %v\n", time.Since(t0))
	}

	// Count nav tags
	navTagCount := 0
	for _, t := range tags {
		if t.IsNav {
			navTagCount++
		}
	}

	// Count GPS photos
	gpsCount := 0
	totalPhotos := 0
	for _, post := range posts {
		totalPhotos += len(post.Photos)
	}

	fmt.Printf("Posts: %d loaded\n", len(posts))
	fmt.Printf("Tags: %d loaded (%d is_nav)\n", len(tags), navTagCount)
	fmt.Printf("Photo Tags: %d loaded\n", len(photoTags))
	fmt.Printf("Areas: %d loaded\n", len(areas))
	fmt.Printf("NavStats: bicycle=%dkm, hike=%dkm\n", sd.NavStats.BicycleDistance, sd.NavStats.HikeDistance)
	_ = gpsCount
	_ = totalPhotos

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
