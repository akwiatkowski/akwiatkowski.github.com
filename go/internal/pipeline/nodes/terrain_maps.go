package nodes

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

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

// Run renders (or skips as fresh) each routed post's terrain maps.
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
	rendered, fresh, failed := 0, 0, 0
	for _, post := range n.posts {
		if !post.HasRoutes() {
			continue
		}
		if !ctx.Force && terrainMapFresh(ctx, post) {
			fresh++
			continue
		}
		if _, err := terrain.Render(post, n.routeColors, opts); err != nil {
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
}

// terrainMapFresh reports whether a post's terrain map is up to date: its output
// SVG exists and is at least as new as the route source. When the source can't
// be located, it's considered fresh if the output exists, so we don't needlessly
// re-render every build.
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
