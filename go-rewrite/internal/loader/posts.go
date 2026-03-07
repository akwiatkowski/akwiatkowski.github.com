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

	"odkrywajac/internal/markdown"
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
	slug := matches[4]

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
		goldmark.WithExtensions(&markdown.Extension{}),
	)
	reader := text.NewReader([]byte(body))
	doc := md.Parser().Parse(reader, goldmarkParser.WithContext(goldmarkParser.NewContext()))
	extracted := markdown.Extract(doc)

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
	post.URL = model.BuildPostURL(post.Date, slug)

	if meta.FinishedAt != nil && !meta.FinishedAt.IsZero() {
		t := meta.FinishedAt.Time
		post.FinishedAt = &t
	}

	// Convert extracted photos to PhotoRefs
	for _, p := range extracted.Photos {
		post.Photos = append(post.Photos, model.PhotoRef{
			Filename: p.Filename,
			Caption:  p.Caption,
			TagSlugs: p.Tags,
		})
	}
	if extracted.HeaderPhoto != nil {
		post.HeaderPhoto = &model.PhotoRef{
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
