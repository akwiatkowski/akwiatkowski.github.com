package pipeline

import (
	"path/filepath"
	"sync"
)

// Context holds configuration and shared state for a pipeline run.
type Context struct {
	Env      string // "dev" or "full"
	Target   string // "local" or "release" (build flavor; also the public/ subdir)
	BasePath string // project root
	Force    bool
	DryRun   bool
	Verbose  bool
	Workers  int

	mu      sync.Mutex
	results map[string]any
}

// StoreResult saves a named result for later retrieval by downstream nodes.
func (c *Context) StoreResult(name string, value any) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.results == nil {
		c.results = make(map[string]any)
	}
	c.results[name] = value
}

// Result retrieves a previously stored result by name.
func (c *Context) Result(name string) (any, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.results == nil {
		return nil, false
	}
	v, ok := c.results[name]
	return v, ok
}

// PostsDir returns the path to post data files.
func (c *Context) PostsDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "data", "posts")
}

// ImagesDir returns the path to image files.
func (c *Context) ImagesDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "data", "images")
}

// RoutesDir returns the path to route/GPX files.
func (c *Context) RoutesDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "data", "routes")
}

// IdeasDir returns the path to trip ideas data files.
func (c *Context) IdeasDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "data", "ideas")
}

// CacheDir returns the path to the Go-specific cache directory.
func (c *Context) CacheDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "cache-go")
}

// OutputDir returns the path to the build output directory. Engine-agnostic:
// keyed only by ENV and TARGET so both engines write the same tree.
func (c *Context) OutputDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "public", c.Target)
}

// IsRelease reports whether this is a release build (drafts hidden, not-ready
// post bodies blanked). Anything other than "release" is treated as local.
func (c *Context) IsRelease() bool {
	return c.Target == "release"
}

// ManifestPath returns the per-engine, per-target render manifest path. Scoped
// by target so switching local<->release never reuses the other's staleness map.
func (c *Context) ManifestPath() string {
	return filepath.Join(c.CacheDir(), "manifest", c.Target+".json")
}

// EngineMarkerPath returns the path of the marker file recording which engine
// last wrote OutputDir. When it disagrees with the current engine, the caller
// forces a full render so the shared output dir ends up wholly owned by one
// engine (bytes may be rewritten identically — that is acceptable).
func (c *Context) EngineMarkerPath() string {
	return filepath.Join(c.OutputDir(), ".engine")
}

// ConfigDir returns the path to shared config files.
func (c *Context) ConfigDir() string {
	return filepath.Join(c.BasePath, "data", "config")
}

// ExternalDir returns the path to external data files (polygons, etc).
func (c *Context) ExternalDir() string {
	return filepath.Join(c.BasePath, "data", "external")
}

// PagesDir returns the path to static page markdown files.
func (c *Context) PagesDir() string {
	return filepath.Join(c.BasePath, "data", "pages")
}

// AssetsDir returns the path to static asset source files. This is the single
// shared source for both engines (the former go-rewrite/assets overlay was
// merged in).
func (c *Context) AssetsDir() string {
	return filepath.Join(c.BasePath, "data", "assets")
}

// AreaCacheDir returns the path to the Crystal-generated area cache.
func (c *Context) AreaCacheDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "cache", "areas_for_post")
}

// ExifCacheDir returns the path to the Go-native EXIF cache directory.
// Contains per-post YAML files named {slug}.yml with image EXIF data.
// Each file is regenerated only when its source images are newer than the cache.
func (c *Context) ExifCacheDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "cache-go", "exifs")
}

// GlobalCacheDir returns the path to the universal (env-independent) cache directory.
// Used for data derived from data/external/ that doesn't vary by environment,
// such as simplified polygon GeoJSON files.
func (c *Context) GlobalCacheDir() string {
	return filepath.Join(c.BasePath, "data", "cache-go")
}

// RouteCoverageDir returns the path to the Go-generated route→area coverage cache.
// Contains per-post YAML files named {slug}.yml with route distances through each area.
func (c *Context) RouteCoverageDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "cache-go", "areas_for_post")
}

// AreaPhotosDir returns the path to the Go-generated photo→area assignment cache.
// Contains per-area YAML files organized by type (e.g., towns/{slug}.yml).
func (c *Context) AreaPhotosDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "cache-go", "photos_in_area")
}
