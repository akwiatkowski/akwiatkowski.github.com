package nodes

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"odkrywajac/internal/model"
	"odkrywajac/internal/pipeline"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/service/terrain"
)

// TerrainMapsNode renders the OSM+hillshade map family (nature, gradient,
// photos, seasonal) and the elevation profile for every post with a route.
// It's a first-class render-pipeline node — the same shape as CopyAssetsNode /
// ProcessImagesNode — so the build clearly shows this new renderer producing
// the per-post maps, rather than it being inline glue in main.
//
// It shells out to GDAL/osmium/rsvg and is slow, so each post is rendered only
// when its route changed (or --force); the whole node is skipped with a message
// when the geo toolchain or the OSM/DEM input data isn't present.
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
	}
	if err := terrain.CheckAvailable(opts); err != nil {
		fmt.Printf("Terrain maps: skipped (%v)\n", err)
		return nil
	}

	var routed []*model.Post
	for _, post := range n.posts {
		if post.HasRoutes() {
			routed = append(routed, post)
		}
	}

	rendered, skipped, failed := 0, 0, 0
	overall := time.Now()
	for i, post := range routed {
		if !ctx.Force && terrainMapExists(ctx, post) {
			skipped++
			continue
		}
		fmt.Printf("  terrain [%d/%d] %s …\n", i+1, len(routed), post.Slug)
		start := time.Now()
		if _, err := terrain.Render(post, n.routeColors, opts); err != nil {
			fmt.Fprintf(os.Stderr, "  terrain %s: %v\n", post.Slug, err)
			failed++
			continue
		}
		if _, err := terrain.RenderElevationProfile(post, opts); err != nil {
			fmt.Fprintf(os.Stderr, "  elevation %s: %v\n", post.Slug, err)
		}
		rendered++
		fmt.Printf("             done in %s\n", time.Since(start).Round(time.Millisecond))
	}
	fmt.Printf("Terrain maps: %d rendered, %d present, %d failed (%s)\n",
		rendered, skipped, failed, time.Since(overall).Round(time.Millisecond))
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
