// Package bundle resolves asset bundle names to CSS/JS file lists.
package bundle

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// AssetFile represents a single CSS or JS file to include.
type AssetFile struct {
	Path      string // e.g. "/css/libs/bootstrap.min.css"
	Integrity string // SRI hash, or ""
	IsCSS     bool   // true=CSS, false=JS
	Version   string // mtime unix timestamp for cache-busting, or ""
}

// VersionedPath returns the path with a ?v= cache-busting query parameter.
func (a AssetFile) VersionedPath() string {
	if a.Version != "" {
		return a.Path + "?v=" + a.Version
	}
	return a.Path
}

// Resolver resolves bundle names to lists of asset files.
type Resolver struct {
	bundles    map[string]*bundleDef
	composites map[string]*compositeDef
	pageAssets map[string]*bundleDef
	integrity  map[string]string // path → SRI hash
	versions   map[string]string // path → mtime unix timestamp (set by PrecomputeVersions)
}

type bundleDef struct {
	CSS       []string          `yaml:"css"`
	JS        []string          `yaml:"js"`
	Integrity map[string]string `yaml:"integrity"`
}

type compositeDef struct {
	Includes []string `yaml:"includes"`
}

type configFile struct {
	Bundles    map[string]*bundleDef    `yaml:"bundles"`
	Composites map[string]*compositeDef `yaml:"composites"`
	PageAssets map[string]*bundleDef    `yaml:"page-assets"`
}

// NewResolver parses the asset_bundles.yml config and creates a Resolver.
func NewResolver(configPath string) (*Resolver, error) {
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("read asset bundles config: %w", err)
	}

	var cfg configFile
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("parse asset bundles config: %w", err)
	}

	// Build global integrity map
	integrity := make(map[string]string)
	for _, b := range cfg.Bundles {
		for path, hash := range b.Integrity {
			integrity[path] = hash
		}
	}

	return &Resolver{
		bundles:    cfg.Bundles,
		composites: cfg.Composites,
		pageAssets: cfg.PageAssets,
		integrity:  integrity,
	}, nil
}

// Resolve expands bundle names (including composites) into a deduplicated, ordered
// list of AssetFile. CSS files come first, then JS files.
func (r *Resolver) Resolve(bundleNames []string) []AssetFile {
	var cssFiles, jsFiles []AssetFile
	seen := make(map[string]bool)

	for _, name := range bundleNames {
		r.expandBundle(name, &cssFiles, &jsFiles, seen)
	}

	return append(cssFiles, jsFiles...)
}

// ResolvePageAssets resolves page-specific asset bundle names.
func (r *Resolver) ResolvePageAssets(names []string) []AssetFile {
	var cssFiles, jsFiles []AssetFile
	seen := make(map[string]bool)

	for _, name := range names {
		if pa, ok := r.pageAssets[name]; ok {
			r.addFiles(pa, &cssFiles, &jsFiles, seen)
		}
	}

	return append(cssFiles, jsFiles...)
}

func (r *Resolver) expandBundle(name string, cssFiles, jsFiles *[]AssetFile, seen map[string]bool) {
	// Check composites first
	if comp, ok := r.composites[name]; ok {
		for _, inc := range comp.Includes {
			r.expandBundle(inc, cssFiles, jsFiles, seen)
		}
		return
	}

	// Check bundles
	if b, ok := r.bundles[name]; ok {
		r.addFiles(b, cssFiles, jsFiles, seen)
	}
}

func (r *Resolver) addFiles(b *bundleDef, cssFiles, jsFiles *[]AssetFile, seen map[string]bool) {
	for _, path := range b.CSS {
		if !seen[path] {
			seen[path] = true
			*cssFiles = append(*cssFiles, AssetFile{
				Path:      path,
				Integrity: r.integrity[path],
				IsCSS:     true,
				Version:   r.versions[path],
			})
		}
	}
	for _, path := range b.JS {
		if !seen[path] {
			seen[path] = true
			*jsFiles = append(*jsFiles, AssetFile{
				Path:      path,
				Integrity: r.integrity[path],
				IsCSS:     false,
				Version:   r.versions[path],
			})
		}
	}
}

// PrecomputeVersions scans the output directory for all known asset files
// and caches their mtime as unix timestamp strings. Subsequent calls to
// Resolve/ResolvePageAssets will include the Version field on each AssetFile.
func (r *Resolver) PrecomputeVersions(outputDir string) {
	r.versions = make(map[string]string)

	// Collect all unique asset paths from bundles and page assets
	paths := make(map[string]bool)
	for _, b := range r.bundles {
		for _, p := range b.CSS {
			paths[p] = true
		}
		for _, p := range b.JS {
			paths[p] = true
		}
	}
	for _, pa := range r.pageAssets {
		for _, p := range pa.CSS {
			paths[p] = true
		}
		for _, p := range pa.JS {
			paths[p] = true
		}
	}

	for p := range paths {
		rel := strings.TrimPrefix(p, "/")
		absPath := filepath.Join(outputDir, rel)
		info, err := os.Stat(absPath)
		if err != nil {
			continue
		}
		r.versions[p] = fmt.Sprintf("%d", info.ModTime().Unix())
	}
}

// BundleNames returns all available bundle names (atomic + composite).
func (r *Resolver) BundleNames() []string {
	var names []string
	for name := range r.bundles {
		names = append(names, name)
	}
	for name := range r.composites {
		names = append(names, name)
	}
	return names
}

// PopulateVersions sets the Version field on each AssetFile by stat'ing
// the corresponding file in outputDir. Version is the file's mtime as
// a unix timestamp string (e.g. "1771078489").
func PopulateVersions(files []AssetFile, outputDir string) {
	for i := range files {
		rel := strings.TrimPrefix(files[i].Path, "/")
		absPath := filepath.Join(outputDir, rel)
		info, err := os.Stat(absPath)
		if err != nil {
			continue
		}
		files[i].Version = fmt.Sprintf("%d", info.ModTime().Unix())
	}
}
