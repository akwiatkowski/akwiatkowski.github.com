package view

import (
	"encoding/xml"
	"fmt"
	"io"
	"sort"
	"time"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
)

// maxFeedPosts is the number of posts to include in RSS/Atom feeds.
const maxFeedPosts = 20

// RSSFeed creates a Renderable for the RSS 2.0 feed.
func RSSFeed(data *catalog.SiteData, rtr *router.Router) Renderable {
	return NewRawEndpoint(rtr.RSSURL(), false, func(w io.Writer) error {
		posts := recentFinishedPosts(data.Posts, maxFeedPosts)

		type rssItem struct {
			XMLName     xml.Name `xml:"item"`
			Title       string   `xml:"title"`
			Link        string   `xml:"link"`
			Description string   `xml:"description"`
			PubDate     string   `xml:"pubDate"`
			GUID        string   `xml:"guid"`
		}

		type rssChannel struct {
			XMLName       xml.Name  `xml:"channel"`
			Title         string    `xml:"title"`
			Link          string    `xml:"link"`
			Description   string    `xml:"description"`
			Language      string    `xml:"language"`
			LastBuildDate string    `xml:"lastBuildDate"`
			Items         []rssItem `xml:"item"`
		}

		type rssFeed struct {
			XMLName xml.Name   `xml:"rss"`
			Version string     `xml:"version,attr"`
			Channel rssChannel `xml:"channel"`
		}

		var items []rssItem
		for _, post := range posts {
			items = append(items, rssItem{
				Title:       post.Title,
				Link:        rtr.CanonicalURL(rtr.PostURL(post)),
				Description: post.Subtitle,
				PubDate:     post.Date.Format(time.RFC1123Z),
				GUID:        rtr.CanonicalURL(rtr.PostURL(post)),
			})
		}

		var lastBuild string
		if len(posts) > 0 {
			lastBuild = posts[0].Date.Format(time.RFC1123Z)
		}

		feed := rssFeed{
			Version: "2.0",
			Channel: rssChannel{
				Title:         data.Config.Title,
				Link:          data.Config.URL,
				Description:   data.Config.Desc,
				Language:      "pl",
				LastBuildDate: lastBuild,
				Items:         items,
			},
		}

		if _, err := io.WriteString(w, xml.Header); err != nil {
			return err
		}
		enc := xml.NewEncoder(w)
		enc.Indent("", "  ")
		return enc.Encode(feed)
	})
}

// AtomFeed creates a Renderable for the Atom 1.0 feed.
func AtomFeed(data *catalog.SiteData, rtr *router.Router) Renderable {
	return NewRawEndpoint(rtr.AtomURL(), false, func(w io.Writer) error {
		posts := recentFinishedPosts(data.Posts, maxFeedPosts)

		type atomLink struct {
			Href string `xml:"href,attr"`
			Rel  string `xml:"rel,attr,omitempty"`
		}

		type atomEntry struct {
			XMLName xml.Name `xml:"entry"`
			Title   string   `xml:"title"`
			Link    atomLink `xml:"link"`
			ID      string   `xml:"id"`
			Updated string   `xml:"updated"`
			Summary string   `xml:"summary"`
		}

		type atomAuthor struct {
			Name  string `xml:"name"`
			Email string `xml:"email,omitempty"`
		}

		type atomFeed struct {
			XMLName xml.Name    `xml:"feed"`
			XMLNS   string      `xml:"xmlns,attr"`
			Title   string      `xml:"title"`
			Link    atomLink    `xml:"link"`
			ID      string      `xml:"id"`
			Updated string      `xml:"updated"`
			Author  atomAuthor  `xml:"author"`
			Entries []atomEntry `xml:"entry"`
		}

		var entries []atomEntry
		for _, post := range posts {
			postURL := rtr.CanonicalURL(rtr.PostURL(post))
			entries = append(entries, atomEntry{
				Title:   post.Title,
				Link:    atomLink{Href: postURL, Rel: "alternate"},
				ID:      postURL,
				Updated: post.Date.Format(time.RFC3339),
				Summary: post.Subtitle,
			})
		}

		var updated string
		if len(posts) > 0 {
			updated = posts[0].Date.Format(time.RFC3339)
		}

		feed := atomFeed{
			XMLNS:   "http://www.w3.org/2005/Atom",
			Title:   data.Config.Title,
			Link:    atomLink{Href: data.Config.URL},
			ID:      data.Config.URL,
			Updated: updated,
			Author: atomAuthor{
				Name:  data.Config.Author,
				Email: data.Config.Email,
			},
			Entries: entries,
		}

		if _, err := io.WriteString(w, xml.Header); err != nil {
			return err
		}
		enc := xml.NewEncoder(w)
		enc.Indent("", "  ")
		return enc.Encode(feed)
	})
}

// Sitemap creates a Renderable for sitemap.xml.
// It must receive all other renderables to collect their URLs.
func Sitemap(all []Renderable, rtr *router.Router) Renderable {
	return NewRawEndpoint(rtr.SitemapURL(), false, func(w io.Writer) error {
		type sitemapURL struct {
			XMLName xml.Name `xml:"url"`
			Loc     string   `xml:"loc"`
		}

		type sitemapURLSet struct {
			XMLName xml.Name     `xml:"urlset"`
			XMLNS   string       `xml:"xmlns,attr"`
			URLs    []sitemapURL `xml:"url"`
		}

		var urls []sitemapURL
		for _, view := range all {
			if view.AddToSitemap() {
				urls = append(urls, sitemapURL{
					Loc: rtr.CanonicalURL(view.URL()),
				})
			}
		}

		urlSet := sitemapURLSet{
			XMLNS: "http://www.sitemaps.org/schemas/sitemap/0.9",
			URLs:  urls,
		}

		if _, err := io.WriteString(w, xml.Header); err != nil {
			return err
		}
		enc := xml.NewEncoder(w)
		enc.Indent("", "  ")
		return enc.Encode(urlSet)
	})
}

// RobotsTxt creates a Renderable for robots.txt.
func RobotsTxt(rtr *router.Router) Renderable {
	return NewRawEndpoint(rtr.RobotsURL(), false, func(w io.Writer) error {
		content := fmt.Sprintf("User-agent: *\nAllow: /\nSitemap: %s\n",
			rtr.CanonicalURL(rtr.SitemapURL()))
		_, err := io.WriteString(w, content)
		return err
	})
}

// recentFinishedPosts returns the most recent N finished posts, sorted by date desc.
func recentFinishedPosts(posts []*model.Post, n int) []*model.Post {
	var finished []*model.Post
	for _, post := range posts {
		if post.IsFinished() {
			finished = append(finished, post)
		}
	}
	sort.Slice(finished, func(i, j int) bool {
		return finished[i].Date.After(finished[j].Date)
	})
	if len(finished) > n {
		finished = finished[:n]
	}
	return finished
}
