package nodes

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"odkrywajac/internal/model"
	"odkrywajac/internal/pipeline"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/service/terrain"
)

// terrainWorkers is how many posts are rendered concurrently. Each render also
// drives multi-threaded external tools (GDAL/rsvg), so a small pool keeps the
// machine busy without oversubscribing it into thrash.
const terrainWorkers = 4

// TerrainMapsNode renders the OSM+hillshade map family (nature, gradient,
// photos, seasonal) and the elevation profile for every post with a route.
// It's a first-class render-pipeline node — the same shape as CopyAssetsNode /
// ProcessImagesNode — so the build clearly shows this new renderer producing
// the per-post maps, rather than it being inline glue in main.
//
// It shells out to GDAL/osmium/rsvg and is slow (~0.5–4 min/post), so posts are
// rendered concurrently (terrainWorkers), only when their map is missing (or
// --force), and the extra variants (gradient/photos/seasonal) are opt-in via
// ctx.TerrainExtras. The whole node is skipped with a message when the geo
// toolchain or the OSM/DEM input data isn't present.
type TerrainMapsNode struct {
	posts       []*model.Post
	routeColors map[string]model.RouteColor
}

// NewTerrainMapsNode creates the node from the loaded posts and route colors.
func NewTerrainMapsNode(posts []*model.Post, routeColors map[string]model.RouteColor) *TerrainMapsNode {
	return &TerrainMapsNode{posts: posts, routeColors: routeColors}
}

func (n *TerrainMapsNode) Name() string { return "renderTerrainMaps" }

// Run renders each routed post's terrain maps. Each render shells out to
// GDAL/osmium/rsvg and takes tens of seconds, so it prints per-post progress
// and timing (otherwise the slow, output-less step looks frozen). A post is
// skipped when its map already exists on disk (see terrainMapExists) unless
// --force — so a whole-site render only fills in the missing ones.
func (n *TerrainMapsNode) Run(ctx *pipeline.Context) error {
	if ctx.DryRun {
		return nil
	}
	opts := terrain.Options{
		OutputDir:  ctx.OutputDir(),
		OSMPBFPath: terrain.DefaultOSMPBF(),
		DEMDir:     terrain.DefaultDEMDir(),
		DTMDir:     terrain.DefaultDTMDir(),
		Verbose:    ctx.Verbose,
		// Extra variants are opt-in (they add cost). Nature + elevation always.
		Gradient: ctx.TerrainExtras,
		Photos:   ctx.TerrainExtras,
		Seasonal: ctx.TerrainExtras,
	}
	if err := terrain.CheckAvailable(opts); err != nil {
		fmt.Printf("Terrain maps: skipped (%v)\n", err)
		return nil
	}

	// Collect the posts that actually need rendering (routed + missing/forced).
	var todo []*model.Post
	skipped := 0
	for _, post := range n.posts {
		if !post.HasRoutes() {
			continue
		}
		if !ctx.Force && terrainMapExists(ctx, post) {
			skipped++
			continue
		}
		todo = append(todo, post)
	}

	overall := time.Now()
	if len(todo) == 0 {
		fmt.Printf("Terrain maps: 0 rendered, %d present, 0 failed (%s)\n", skipped, time.Since(overall).Round(time.Millisecond))
		return nil
	}
	fmt.Printf("Terrain maps: rendering %d posts (%d present) with %d workers…\n", len(todo), skipped, terrainWorkers)

	// Render concurrently: posts are independent (each writes its own files and
	// its own temp dirs). A mutex serializes the progress output and counters.
	var (
		mu             sync.Mutex
		rendered, fail int
		jobs           = make(chan *model.Post)
		wg             sync.WaitGroup
	)
	for w := 0; w < terrainWorkers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for post := range jobs {
				start := time.Now()
				if _, err := terrain.Render(post, n.routeColors, opts); err != nil {
					mu.Lock()
					fmt.Fprintf(os.Stderr, "  terrain %s: %v\n", post.Slug, err)
					fail++
					mu.Unlock()
					continue
				}
				if _, err := terrain.RenderElevationProfile(post, opts); err != nil {
					mu.Lock()
					fmt.Fprintf(os.Stderr, "  elevation %s: %v\n", post.Slug, err)
					mu.Unlock()
				}
				mu.Lock()
				rendered++
				fmt.Printf("  terrain [%d/%d] %s — %s\n", rendered+fail, len(todo), post.Slug, time.Since(start).Round(time.Millisecond))
				mu.Unlock()
			}
		}()
	}
	for _, post := range todo {
		jobs <- post
	}
	close(jobs)
	wg.Wait()

	fmt.Printf("Terrain maps: %d rendered, %d present, %d failed (%s)\n",
		rendered, skipped, fail, time.Since(overall).Round(time.Millisecond))
	return nil
}

// terrainMapExists reports whether a post's terrain map is already on disk. The
// terrain render is expensive and rarely changes, so a whole-site build only
// renders posts whose map is missing; use --force to re-render existing ones.
func terrainMapExists(ctx *pipeline.Context, post *model.Post) bool {
	outSVG := filepath.Join(ctx.OutputDir(), filepath.FromSlash(strings.TrimPrefix(router.PostMapPath(post, "-osm-nature.svg"), "/")))
	_, err := os.Stat(outSVG)
	return err == nil
}
