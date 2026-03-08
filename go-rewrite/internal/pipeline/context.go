package pipeline

import (
	"path/filepath"
	"sync"
)

// Context holds configuration and shared state for a pipeline run.
type Context struct {
	Env      string // "dev" or "full"
	Target   string // "go"
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

// CacheDir returns the path to the Go-specific cache directory.
func (c *Context) CacheDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "cache-go")
}

// OutputDir returns the path to the build output directory.
func (c *Context) OutputDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "public", c.Target)
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

// AssetsDir returns the path to static asset source files.
func (c *Context) AssetsDir() string {
	return filepath.Join(c.BasePath, "data", "assets")
}

// GoAssetsDir returns the path to Go-specific asset overrides.
func (c *Context) GoAssetsDir() string {
	return filepath.Join(c.BasePath, "go-rewrite", "assets")
}

// AreaCacheDir returns the path to the Crystal-generated area cache.
func (c *Context) AreaCacheDir() string {
	return filepath.Join(c.BasePath, "env", c.Env, "cache", "areas_for_post")
}

// GeneratedCacheDir returns the path to the generated cache directory.
func (c *Context) GeneratedCacheDir() string {
	return filepath.Join(c.BasePath, "go-rewrite", "cache")
}
