package loader

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

// LoadSiteConfig parses config.yml dot-notation keys into SiteConfig.
func LoadSiteConfig(path string) (model.SiteConfig, error) {
	f, err := os.Open(path)
	if err != nil {
		return model.SiteConfig{}, fmt.Errorf("open config: %w", err)
	}
	defer f.Close()

	kv := make(map[string]string)
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		// Remove surrounding quotes
		val = strings.Trim(val, `"`)
		kv[key] = val
	}
	if err := scanner.Err(); err != nil {
		return model.SiteConfig{}, fmt.Errorf("scan config: %w", err)
	}

	return model.SiteConfig{
		Title:  kv["site.title"],
		URL:    kv["site.url"],
		Author: kv["site.author"],
		Email:  kv["site.email"],
		Desc:   kv["site.desc"],
	}, nil
}

// LoadTags loads tag definitions from a YAML file.
func LoadTags(path string) ([]model.Tag, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read tags: %w", err)
	}
	var tags []model.Tag
	if err := yaml.Unmarshal(data, &tags); err != nil {
		return nil, fmt.Errorf("parse tags: %w", err)
	}
	return tags, nil
}

// LoadPhotoTags loads photo tag definitions from a YAML file.
func LoadPhotoTags(path string) ([]model.PhotoTag, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read photo_tags: %w", err)
	}
	var tags []model.PhotoTag
	if err := yaml.Unmarshal(data, &tags); err != nil {
		return nil, fmt.Errorf("parse photo_tags: %w", err)
	}
	return tags, nil
}

// LoadRouteColors loads route color definitions from a YAML file.
func LoadRouteColors(path string) (map[string]model.RouteColor, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read route_colors: %w", err)
	}
	var colors map[string]model.RouteColor
	if err := yaml.Unmarshal(data, &colors); err != nil {
		return nil, fmt.Errorf("parse route_colors: %w", err)
	}
	return colors, nil
}

// LoadTrainStations loads train station definitions from a YAML file.
func LoadTrainStations(path string) ([]model.TrainStation, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read train_stations: %w", err)
	}
	var stations []model.TrainStation
	if err := yaml.Unmarshal(data, &stations); err != nil {
		return nil, fmt.Errorf("parse train_stations: %w", err)
	}
	return stations, nil
}

// LoadTransportPOIs loads transport POI definitions from a YAML file.
func LoadTransportPOIs(path string) ([]model.TransportPOI, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read transport_pois: %w", err)
	}
	var pois []model.TransportPOI
	if err := yaml.Unmarshal(data, &pois); err != nil {
		return nil, fmt.Errorf("parse transport_pois: %w", err)
	}
	return pois, nil
}

// LoadAllConfigs loads all config files from a config directory in parallel.
func LoadAllConfigs(configDir string) (
	cfg model.SiteConfig,
	tags []model.Tag,
	photoTags []model.PhotoTag,
	routeColors map[string]model.RouteColor,
	stations []model.TrainStation,
	pois []model.TransportPOI,
	err error,
) {
	type result struct {
		idx int
		val any
		err error
	}
	ch := make(chan result, 6)

	go func() {
		v, e := LoadSiteConfig(filepath.Join(configDir, "config.yml"))
		ch <- result{0, v, e}
	}()
	go func() {
		v, e := LoadTags(filepath.Join(configDir, "tags.yml"))
		ch <- result{1, v, e}
	}()
	go func() {
		v, e := LoadPhotoTags(filepath.Join(configDir, "photo_tags.yml"))
		ch <- result{2, v, e}
	}()
	go func() {
		v, e := LoadRouteColors(filepath.Join(configDir, "route_colors.yml"))
		ch <- result{3, v, e}
	}()
	go func() {
		v, e := LoadTrainStations(filepath.Join(configDir, "train_stations.yml"))
		ch <- result{4, v, e}
	}()
	go func() {
		v, e := LoadTransportPOIs(filepath.Join(configDir, "transport_pois.yml"))
		ch <- result{5, v, e}
	}()

	for range 6 {
		r := <-ch
		if r.err != nil {
			err = r.err
			return
		}
		switch r.idx {
		case 0:
			cfg = r.val.(model.SiteConfig)
		case 1:
			tags = r.val.([]model.Tag)
		case 2:
			photoTags = r.val.([]model.PhotoTag)
		case 3:
			routeColors = r.val.(map[string]model.RouteColor)
		case 4:
			stations = r.val.([]model.TrainStation)
		case 5:
			pois = r.val.([]model.TransportPOI)
		}
	}
	return
}
