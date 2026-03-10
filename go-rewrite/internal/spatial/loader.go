package spatial

import (
	"fmt"
	"os"
	"path/filepath"

	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

// LoadExternalAreas loads all area polygons from data/external/*.yaml files
// and converts them to ExternalArea format for use by the Matcher.
// This mirrors geodata.LoadExternalAreas but returns the spatial package's type.
func LoadExternalAreas(externalDir string) (map[string][]ExternalArea, error) {
	result := make(map[string][]ExternalArea)
	for _, areaType := range model.AllAreaTypes() {
		typeName := areaType.EnglishPlural()
		path := filepath.Join(externalDir, typeName+".yaml")

		data, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", path, err)
		}

		var areas []ExternalArea
		if err := yaml.Unmarshal(data, &areas); err != nil {
			return nil, fmt.Errorf("parse %s: %w", path, err)
		}

		result[typeName] = areas
	}
	return result, nil
}
