package render

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// ManifestEntry tracks a single output file.
type ManifestEntry struct {
	SHA256  string `json:"sha256"`
	Size    int    `json:"size"`
	BuiltAt string `json:"built_at"`
}

// Manifest tracks all output files for incremental builds and FTP sync.
type Manifest struct {
	BuiltAt string                   `json:"built_at"`
	Env     string                   `json:"env"`
	Target  string                   `json:"target"`
	Files   map[string]ManifestEntry `json:"files"`

	mu sync.Mutex
}

// NewManifest creates a new empty manifest.
func NewManifest(env, target string) *Manifest {
	return &Manifest{
		Env:    env,
		Target: target,
		Files:  make(map[string]ManifestEntry),
	}
}

// LoadManifest loads a manifest from disk. Returns a new empty manifest if file doesn't exist.
func LoadManifest(path, env, target string) *Manifest {
	data, err := os.ReadFile(path)
	if err != nil {
		return NewManifest(env, target)
	}

	var m Manifest
	if err := json.Unmarshal(data, &m); err != nil {
		return NewManifest(env, target)
	}
	if m.Files == nil {
		m.Files = make(map[string]ManifestEntry)
	}
	return &m
}

// Get returns the manifest entry for a URL, or empty entry if not found.
func (m *Manifest) Get(url string) (ManifestEntry, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	e, ok := m.Files[url]
	return e, ok
}

// Set updates the manifest entry for a URL.
func (m *Manifest) Set(url string, entry ManifestEntry) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.Files[url] = entry
}

// Save writes the manifest to disk as JSON.
func (m *Manifest) Save(path string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.BuiltAt = time.Now().UTC().Format(time.RFC3339)

	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal manifest: %w", err)
	}

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("mkdir for manifest: %w", err)
	}

	return os.WriteFile(path, data, 0o644)
}

// Len returns the number of entries in the manifest.
func (m *Manifest) Len() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.Files)
}
