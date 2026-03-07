package loader

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// devPostsDir returns the dev environment posts directory.
func devPostsDir(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for {
		path := filepath.Join(dir, "env", "dev", "data", "posts")
		if _, err := os.Stat(path); err == nil {
			return path
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Skip("could not find dev posts directory")
		}
		dir = parent
	}
}

func devRoutesDir(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for {
		path := filepath.Join(dir, "env", "dev", "data", "routes")
		if _, err := os.Stat(path); err == nil {
			return path
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Skip("could not find dev routes directory")
		}
		dir = parent
	}
}

func TestLoadPosts(t *testing.T) {
	postsDir := devPostsDir(t)
	routesDir := devRoutesDir(t)

	posts, err := LoadPosts(postsDir, routesDir)
	if err != nil {
		t.Fatal(err)
	}

	if len(posts) != 6 {
		t.Errorf("expected 6 dev posts, got %d", len(posts))
	}

	// Posts should be sorted by date descending
	for i := 1; i < len(posts); i++ {
		if posts[i].Date.After(posts[i-1].Date) {
			t.Errorf("posts not sorted: %s (%v) after %s (%v)",
				posts[i].Slug, posts[i].Date, posts[i-1].Slug, posts[i-1].Date)
		}
	}
}

func TestLoadPostFields(t *testing.T) {
	postsDir := devPostsDir(t)
	routesDir := devRoutesDir(t)

	posts, err := LoadPosts(postsDir, routesDir)
	if err != nil {
		t.Fatal(err)
	}

	// Find the pagorki post
	var pagorki *struct {
		post interface{ Year() int }
	}
	for _, p := range posts {
		if p.Slug == "pagorki-przed-zniwami" {
			if p.Title != "Pagórki przed żniwami" {
				t.Errorf("Title = %q", p.Title)
			}
			if p.Year() != 2021 {
				t.Errorf("Year = %d", p.Year())
			}
			if p.URL != "/2021/07/18-pagorki-przed-zniwami.html" {
				t.Errorf("URL = %q", p.URL)
			}
			if p.Distance != 69 {
				t.Errorf("Distance = %v", p.Distance)
			}
			if p.CoordsType != "bicycle" {
				t.Errorf("CoordsType = %q", p.CoordsType)
			}
			if len(p.TagSlugs) < 2 {
				t.Errorf("TagSlugs = %v", p.TagSlugs)
			}
			if len(p.TownSlugs) < 2 {
				t.Errorf("TownSlugs = %v", p.TownSlugs)
			}
			if p.FinishedAt == nil {
				t.Error("FinishedAt should not be nil")
			}
			if p.Temperature == nil || *p.Temperature != 29 {
				t.Errorf("Temperature = %v", p.Temperature)
			}
			pagorki = nil // just to use the var
			_ = pagorki
			return
		}
	}
	t.Error("pagorki-przed-zniwami not found")
}

func TestLoadPostPhotos(t *testing.T) {
	postsDir := devPostsDir(t)
	routesDir := devRoutesDir(t)

	posts, err := LoadPosts(postsDir, routesDir)
	if err != nil {
		t.Fatal(err)
	}

	for _, p := range posts {
		if p.Slug == "pagorki-przed-zniwami" {
			// Should have many photos
			if len(p.Photos) < 10 {
				t.Errorf("expected 10+ photos, got %d", len(p.Photos))
			}

			// Check header photo
			if p.HeaderPhoto == nil {
				t.Error("expected header photo")
			} else if !p.HeaderPhoto.IsHeader {
				t.Error("header photo should have IsHeader=true")
			}

			// Check a tagged photo
			for _, photo := range p.Photos {
				if strings.Contains(photo.Caption, "Modraszek") && len(photo.TagSlugs) > 0 {
					return // found a photo with tags
				}
			}
			t.Log("warning: no tagged photos found")
			return
		}
	}
}

func TestLoadPostRoutes(t *testing.T) {
	postsDir := devPostsDir(t)
	routesDir := devRoutesDir(t)

	posts, err := LoadPosts(postsDir, routesDir)
	if err != nil {
		t.Fatal(err)
	}

	for _, p := range posts {
		if p.Slug == "spacer-na-przedmiescia" {
			if len(p.Routes) != 1 {
				t.Fatalf("expected 1 route, got %d", len(p.Routes))
			}
			r := p.Routes[0]
			if r.Type != "hike" {
				t.Errorf("route type = %q, want hike", r.Type)
			}
			if len(r.Segments) < 1 {
				t.Error("expected at least 1 segment")
			}
			if len(r.Segments[0]) < 10 {
				t.Errorf("expected 10+ points in segment, got %d", len(r.Segments[0]))
			}
			return
		}
	}
	t.Error("spacer-na-przedmiescia not found")
}

func TestLoadPostCrossRefs(t *testing.T) {
	postsDir := devPostsDir(t)
	routesDir := devRoutesDir(t)

	posts, err := LoadPosts(postsDir, routesDir)
	if err != nil {
		t.Fatal(err)
	}

	for _, p := range posts {
		if p.Slug == "pagorki-przed-zniwami" {
			if len(p.CrossRefSlugs) < 1 {
				t.Error("expected at least 1 cross-reference")
			}
			return
		}
	}
}

func TestSlugFromFilename(t *testing.T) {
	tests := []struct {
		filename, want string
	}{
		{"2021-07-18-pagorki-przed-zniwami.md", "pagorki-przed-zniwami"},
		{"2018-11-05-spacer-na-przedmiescia.md", "spacer-na-przedmiescia"},
	}
	for _, tt := range tests {
		got := SlugFromFilename(tt.filename)
		if got != tt.want {
			t.Errorf("SlugFromFilename(%q) = %q, want %q", tt.filename, got, tt.want)
		}
	}
}

func TestSplitFrontMatter(t *testing.T) {
	input := "---\ntitle: Hello\n---\nBody text"
	fm, body, err := splitFrontMatter(input)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(fm, "title: Hello") {
		t.Errorf("front matter = %q", fm)
	}
	if !strings.Contains(body, "Body text") {
		t.Errorf("body = %q", body)
	}
}
