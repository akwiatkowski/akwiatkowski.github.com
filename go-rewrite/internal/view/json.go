package view

import (
	"odkrywajac/internal/index"
	"odkrywajac/internal/router"
)

// E2EJSON creates a JSON endpoint with all post data for E2E tests.
func E2EJSON(data *index.SiteData, r *router.Router) Renderable {
	type postEntry struct {
		Slug     string   `json:"slug"`
		Title    string   `json:"title"`
		URL      string   `json:"url"`
		Date     string   `json:"date"`
		Tags     []string `json:"tags"`
		Towns    []string `json:"towns,omitempty"`
		Lands    []string `json:"lands,omitempty"`
		Distance float64  `json:"distance,omitempty"`
	}

	type e2eData struct {
		Posts []postEntry `json:"posts"`
	}

	result := e2eData{}
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		result.Posts = append(result.Posts, postEntry{
			Slug:     post.Slug,
			Title:    post.Title,
			URL:      r.PostURL(post),
			Date:     post.Date.Format("2006-01-02"),
			Tags:     post.TagSlugs,
			Towns:    post.TownSlugs,
			Lands:    post.LandSlugs,
			Distance: post.Distance,
		})
	}

	return NewJSONEndpoint(r.E2EJSON(), result)
}
