package strava

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// IgnoredActivity is one entry of the skip-list of activities that will
// intentionally never get a blog post (commutes, tests, duplicates, private
// rides). The list lives outside the blog repo on purpose — see
// ~/projects/llm/input/cycling/ignored_activities.yml — and is maintained by
// the trip-draft-post skill when Olek marks a ride as not worth a post.
type IgnoredActivity struct {
	ID        int64  `yaml:"id"`
	Name      string `yaml:"name"`
	Date      string `yaml:"date"`
	Reason    string `yaml:"reason"`
	IgnoredAt string `yaml:"ignored_at"`
}

// ignoredFile mirrors the YAML document shape: a single `ignored:` list.
type ignoredFile struct {
	Ignored []IgnoredActivity `yaml:"ignored"`
}

// LoadIgnoredIDs reads the skip-list YAML and returns the set of ignored
// activity IDs. A missing file is not an error — it simply means nothing is
// ignored — so `missing-posts` keeps working on machines without the list.
func LoadIgnoredIDs(path string) (map[int64]bool, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return map[int64]bool{}, nil
		}
		return nil, fmt.Errorf("read ignored activities file: %w", err)
	}

	var file ignoredFile
	if err := yaml.Unmarshal(data, &file); err != nil {
		return nil, fmt.Errorf("parse ignored activities file %s: %w", path, err)
	}

	ids := make(map[int64]bool, len(file.Ignored))
	for _, entry := range file.Ignored {
		ids[entry.ID] = true
	}
	return ids, nil
}
