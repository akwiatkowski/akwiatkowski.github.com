package loader

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"sync"

	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

// LoadAreas loads all 5 area types from YAML configs in the given directory
// and returns them combined. The areasDir should contain towns.yml, counties.yml,
// voivodeships.yml, meso_regions.yml, and macro_regions.yml.
func LoadAreas(areasDir string) ([]*model.Area, error) {
	areaTypes := model.AllAreaTypes()

	type result struct {
		areaType model.AreaType
		areas    []*model.Area
		err      error
	}

	ch := make(chan result, len(areaTypes))
	var wg sync.WaitGroup

	for _, at := range areaTypes {
		wg.Add(1)
		go func(at model.AreaType) {
			defer wg.Done()
			path := filepath.Join(areasDir, at.ConfigFilename())
			areas, err := loadAreasFile(path, at)
			ch <- result{at, areas, err}
		}(at)
	}

	go func() {
		wg.Wait()
		close(ch)
	}()

	var all []*model.Area
	for r := range ch {
		if r.err != nil {
			return nil, fmt.Errorf("load %s: %w", r.areaType.EnglishPlural(), r.err)
		}
		all = append(all, r.areas...)
	}

	// Sort by type then slug for stable ordering
	sort.Slice(all, func(i, j int) bool {
		if all[i].Type != all[j].Type {
			return all[i].Type < all[j].Type
		}
		return all[i].Slug < all[j].Slug
	})

	return all, nil
}

func loadAreasFile(path string, areaType model.AreaType) ([]*model.Area, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", path, err)
	}

	var areas []*model.Area
	if err := yaml.Unmarshal(data, &areas); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}

	// Set the type on each area
	for _, a := range areas {
		a.Type = areaType
	}

	return areas, nil
}
