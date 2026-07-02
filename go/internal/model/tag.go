package model

// Tag represents a content category (e.g., bicycle, hike, photo).
type Tag struct {
	Slug   string `yaml:"slug"`
	SlugPl string `yaml:"slug_pl"`
	Name   string `yaml:"name"`
	IsNav  bool   `yaml:"is_nav"`
}

// PhotoTag represents a photo classification with scoring points.
type PhotoTag struct {
	Slug     string `yaml:"slug"`
	SlugPl   string `yaml:"slug_pl"`
	Title    string `yaml:"title"`
	Subtitle string `yaml:"subtitle"`
	Points   int    `yaml:"points"`
}
