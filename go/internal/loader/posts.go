package loader

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"odkrywajac/internal/content"
	"odkrywajac/internal/model"

	"github.com/yuin/goldmark"
	goldmarkParser "github.com/yuin/goldmark/parser"
	"github.com/yuin/goldmark/text"
	"gopkg.in/yaml.v3"
)

// postFrontMatter is the raw YAML front matter structure.
type postFrontMatter struct {
	Layout        string    `yaml:"layout"`
	Title         string    `yaml:"title"`
	Subtitle      string    `yaml:"subtitle"`
	Desc          string    `yaml:"desc"`
	Keywords      []string  `yaml:"keywords"`
	Date          time.Time `yaml:"date"`
	FinishedAt    *yamlTime `yaml:"finished_at"`
	Author        string    `yaml:"author"`
	Categories    string    `yaml:"categories"`
	ImageFilename string    `yaml:"image_filename"`
	ImagePosition string    `yaml:"image_position"`
	Tags          []string  `yaml:"tags"`
	Towns         []string  `yaml:"towns"`
	Lands         []string  `yaml:"lands"`
	Foreign       []string  `yaml:"foreign"`
	CoordsFile    string    `yaml:"coords_file"`
	CoordsType    string    `yaml:"coords_type"`
	Distance      float64   `yaml:"distance"`
	TimeSpent     float64   `yaml:"time_spent"`
	Elevation     int       `yaml:"elevation"`
	Temperature   *int      `yaml:"temperature"`
	Strava        yamlStrava `yaml:"strava"`
}

// yamlTime handles optional time.Time fields (commented-out dates become nil).
type yamlTime struct {
	time.Time
}

func (t *yamlTime) UnmarshalYAML(value *yaml.Node) error {
	if value.Value == "" {
		return nil
	}
	var tt time.Time
	if err := value.Decode(&tt); err != nil {
		return err
	}
	t.Time = tt
	return nil
}

// yamlStrava handles strava field which can be int64, string, or []string.
type yamlStrava struct {
	Values []string
}

func (s *yamlStrava) UnmarshalYAML(value *yaml.Node) error {
	switch value.Kind {
	case yaml.ScalarNode:
		if value.Value != "" && value.Value != "~" {
			s.Values = []string{value.Value}
		}
	case yaml.SequenceNode:
		var items []string
		if err := value.Decode(&items); err != nil {
			return err
		}
		s.Values = items
	}
	return nil
}

// filenamePattern extracts date and slug from post filenames.
// Example: 2021-07-18-pagorki-przed-zniwami.md
var filenamePattern = regexp.MustCompile(`^(\d{4})-(\d{2})-(\d{2})-(.+)\.md$`)

// LoadPosts loads all posts from a directory and their route files.
func LoadPosts(postsDir, routesDir string) ([]*model.Post, error) {
	var mdFiles []string
	err := filepath.WalkDir(postsDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() && strings.HasSuffix(path, ".md") {
			mdFiles = append(mdFiles, path)
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("walk posts dir: %w", err)
	}

	type result struct {
		post *model.Post
		err  error
	}

	ch := make(chan result, len(mdFiles))
	var wg sync.WaitGroup

	for _, path := range mdFiles {
		wg.Add(1)
		go func(path string) {
			defer wg.Done()
			post, err := loadPost(path, routesDir)
			ch <- result{post, err}
		}(path)
	}

	go func() {
		wg.Wait()
		close(ch)
	}()

	var posts []*model.Post
	for r := range ch {
		if r.err != nil {
			return nil, r.err
		}
		// Skip posts tagged "hidden" — they should not appear anywhere
		if r.post.HasTag("hidden") {
			continue
		}
		posts = append(posts, r.post)
	}

	// Sort by date descending
	sort.Slice(posts, func(i, j int) bool {
		return posts[i].Date.After(posts[j].Date)
	})

	return posts, nil
}

func loadPost(path, routesDir string) (*model.Post, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read post %s: %w", path, err)
	}

	// Extract slug from filename
	base := filepath.Base(path)
	matches := filenamePattern.FindStringSubmatch(base)
	if matches == nil {
		return nil, fmt.Errorf("invalid post filename: %s", base)
	}
	slug := strings.TrimSuffix(base, ".md")

	// Split front matter and body
	fm, body, err := splitFrontMatter(string(data))
	if err != nil {
		return nil, fmt.Errorf("front matter in %s: %w", base, err)
	}

	// Parse front matter
	var meta postFrontMatter
	if err := yaml.Unmarshal([]byte(fm), &meta); err != nil {
		return nil, fmt.Errorf("parse front matter in %s: %w", base, err)
	}

	// Parse markdown body with goldmark to extract photos and cross-refs
	md := goldmark.New(
		goldmark.WithExtensions(&content.Extension{}),
	)
	reader := text.NewReader([]byte(body))
	doc := md.Parser().Parse(reader, goldmarkParser.WithContext(goldmarkParser.NewContext()))
	extracted := content.Extract(doc)

	// Build post
	post := &model.Post{
		Slug:          slug,
		Title:         meta.Title,
		Subtitle:      meta.Subtitle,
		Desc:          meta.Desc,
		Author:        meta.Author,
		Category:      meta.Categories,
		Date:          meta.Date,
		Keywords:      ensureSlice(meta.Keywords),
		ImageFilename: meta.ImageFilename,
		ImagePosition: meta.ImagePosition,
		TagSlugs:      ensureSlice(meta.Tags),
		TownSlugs:     ensureSlice(meta.Towns),
		LandSlugs:     ensureSlice(meta.Lands),
		ForeignSlugs:  ensureSlice(meta.Foreign),
		CoordsFile:    meta.CoordsFile,
		CoordsType:    meta.CoordsType,
		Distance:      meta.Distance,
		TimeSpent:     meta.TimeSpent,
		Elevation:     meta.Elevation,
		Temperature:   meta.Temperature,
		Strava:        meta.Strava.Values,
		Content:       body,
		CrossRefSlugs: extracted.CrossRefs,
	}
	// URL derives path from date + slug: /2021/07/24-w-trakcie-zniw.html
	post.URL = fmt.Sprintf("/%d/%02d/%s.html",
		post.Date.Year(), post.Date.Month(), slug[8:])

	if meta.FinishedAt != nil && !meta.FinishedAt.IsZero() {
		t := meta.FinishedAt.Time
		post.FinishedAt = &t
	}

	// Convert extracted photos to PublishedPhotoRefs
	for _, p := range extracted.Photos {
		post.PublishedPhotoRefs = append(post.PublishedPhotoRefs, model.PhotoRef{
			Filename: p.Filename,
			Caption:  p.Caption,
			TagSlugs: p.Tags,
		})
	}
	if extracted.HeaderPhoto != nil {
		post.HeaderPhotoRef = &model.PhotoRef{
			Filename: post.ImageFilename, // header photo uses post's main image
			Caption:  extracted.HeaderPhoto.Caption,
			TagSlugs: extracted.HeaderPhoto.Tags,
			IsHeader: true,
		}
	}

	// Load route coordinates
	if meta.CoordsFile != "" {
		routes, err := loadRouteFile(filepath.Join(routesDir, meta.CoordsFile), meta.CoordsType)
		if err != nil {
			// Route file might not exist — non-fatal
			_ = err
		} else {
			post.Routes = routes
		}
	}

	return post, nil
}

// splitFrontMatter splits "---\nfm\n---\nbody" into front matter and body strings.
func splitFrontMatter(content string) (string, string, error) {
	// Must start with ---
	if !strings.HasPrefix(content, "---") {
		return "", "", fmt.Errorf("missing front matter delimiter")
	}

	// Find the closing ---
	rest := content[3:]
	// Skip the first newline after opening ---
	if idx := strings.Index(rest, "\n"); idx >= 0 {
		rest = rest[idx+1:]
	}

	end := strings.Index(rest, "\n---")
	if end < 0 {
		return "", "", fmt.Errorf("missing closing front matter delimiter")
	}

	fm := rest[:end]
	body := rest[end+4:] // skip "\n---"
	// Skip newline after closing ---
	if len(body) > 0 && body[0] == '\n' {
		body = body[1:]
	}

	return fm, body, nil
}

// loadRouteFile loads route coordinates from a JSON file.
// Format: [[[lat, lon], ...], [[lat, lon], ...]] — array of segments.
func loadRouteFile(path, routeType string) ([]model.Route, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var raw [][][2]float64
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("parse route %s: %w", path, err)
	}

	var segments [][]model.LatLon
	for _, seg := range raw {
		var points []model.LatLon
		for _, coord := range seg {
			points = append(points, model.LatLon{Lat: coord[0], Lon: coord[1]})
		}
		if len(points) > 0 {
			segments = append(segments, points)
		}
	}

	if len(segments) == 0 {
		return nil, nil
	}

	return []model.Route{{Type: routeType, Segments: segments}}, nil
}

func ensureSlice(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

// areaCoverageRef is one area entry inside a route's coverage record: which
// area the route crossed and how much of the route ran through it.
type areaCoverageRef struct {
	Slug            string  `yaml:"slug"`
	DistancePercent float64 `yaml:"distance_percent"`
}

// areaRouteSegment represents one route's area assignments from the coverage
// cache (env/<env>/cache-go/areas_for_post/<slug>.yml, one entry per route).
type areaRouteSegment struct {
	Towns        []areaCoverageRef `yaml:"towns"`
	Counties     []areaCoverageRef `yaml:"counties"`
	Voivodeships []areaCoverageRef `yaml:"voivodeships"`
	MesoRegions  []areaCoverageRef `yaml:"meso_regions"`
	MacroRegions []areaCoverageRef `yaml:"macro_regions"`
}

// areaCoverageThresholdPercent filters out areas a route merely clipped.
// Mirrors Crystal's AreaDataLoader::THRESHOLD_DEFAULT (1.0%): an area counts
// as visited only when at least 1% of the route's distance ran through it,
// otherwise border towns touched for a few meters would get their own pages.
const areaCoverageThresholdPercent = 1.0

// EnrichPostsWithAreaCache reads the route→area coverage cache and fills each
// post's SpatialAreaSlugs with every area type the route passed through
// (towns, counties, voivodeships, meso and macro regions). This is what lets
// area show/post-list pages exist for areas the author never listed in the
// frontmatter — exact disambiguated town slugs, counties, macro regions.
// Meso regions are additionally merged into LandSlugs, which post views render
// as the "Krainy" links.
func EnrichPostsWithAreaCache(posts []*model.Post, cacheDir string) {
	if _, err := os.Stat(cacheDir); err != nil {
		return // cache dir doesn't exist, skip silently
	}

	for _, post := range posts {
		filename := post.Slug + ".yml"
		path := filepath.Join(cacheDir, filename)

		data, err := os.ReadFile(path)
		if err != nil {
			continue // no cache file for this post
		}

		var segments []areaRouteSegment
		if err := yaml.Unmarshal(data, &segments); err != nil {
			continue
		}

		spatial := make(map[model.AreaType][]string)
		for _, seg := range segments {
			perType := map[model.AreaType][]areaCoverageRef{
				model.AreaTypeTown:        seg.Towns,
				model.AreaTypeCounty:      seg.Counties,
				model.AreaTypeVoivodeship: seg.Voivodeships,
				model.AreaTypeMesoRegion:  seg.MesoRegions,
				model.AreaTypeMacroRegion: seg.MacroRegions,
			}
			for areaType, refs := range perType {
				for _, ref := range refs {
					if ref.Slug == "" || ref.DistancePercent < areaCoverageThresholdPercent {
						continue
					}
					if !containsString(spatial[areaType], ref.Slug) {
						spatial[areaType] = append(spatial[areaType], ref.Slug)
					}
				}
			}
		}
		if len(spatial) > 0 {
			post.SpatialAreaSlugs = spatial
		}

		// Keep the historical behavior: meso regions also feed LandSlugs,
		// which post article views render as "Krainy" links.
		for _, slug := range spatial[model.AreaTypeMesoRegion] {
			if !containsString(post.LandSlugs, slug) {
				post.LandSlugs = append(post.LandSlugs, slug)
			}
		}
	}
}

// containsString reports whether list already holds value. The slug lists are
// tiny (a handful of areas per post), so linear scan beats a map allocation.
func containsString(list []string, value string) bool {
	for _, item := range list {
		if item == value {
			return true
		}
	}
	return false
}

// SlugFromFilename extracts post slug from a filename like "2021-07-18-pagorki-przed-zniwami.md".
func SlugFromFilename(filename string) string {
	matches := filenamePattern.FindStringSubmatch(filename)
	if matches == nil {
		return ""
	}
	return matches[4]
}

// DateFromFilename extracts the date from a post filename.
func DateFromFilename(filename string) (time.Time, error) {
	matches := filenamePattern.FindStringSubmatch(filename)
	if matches == nil {
		return time.Time{}, fmt.Errorf("invalid filename: %s", filename)
	}
	year, _ := strconv.Atoi(matches[1])
	month, _ := strconv.Atoi(matches[2])
	day, _ := strconv.Atoi(matches[3])
	return time.Date(year, time.Month(month), day, 0, 0, 0, 0, time.UTC), nil
}
