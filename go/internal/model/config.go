package model

// SiteConfig holds top-level site metadata from config.yml.
type SiteConfig struct {
	Title  string
	URL    string
	Author string
	Email  string
	Desc   string
}

// RouteColor defines how a transport type's route is drawn on maps.
type RouteColor struct {
	Color   string  `yaml:"color"`
	Weight  int     `yaml:"weight"`
	Opacity float64 `yaml:"opacity"`
}
