package catalog

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

// LoadIdeas loads all idea YAML files from the ideas directory.
// Each .yaml file contains a single idea definition.
func LoadIdeas(ideasDir string) ([]model.Idea, error) {
	entries, err := os.ReadDir(ideasDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("read ideas dir: %w", err)
	}

	var ideas []model.Idea
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".yaml") {
			continue
		}
		data, err := os.ReadFile(filepath.Join(ideasDir, entry.Name()))
		if err != nil {
			return nil, fmt.Errorf("read idea %s: %w", entry.Name(), err)
		}
		var idea model.Idea
		if err := yaml.Unmarshal(data, &idea); err != nil {
			return nil, fmt.Errorf("parse idea %s: %w", entry.Name(), err)
		}
		ideas = append(ideas, idea)
	}
	return ideas, nil
}
