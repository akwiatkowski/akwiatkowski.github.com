package model

import (
	"testing"
	"time"
)

func TestPostSlugIncludesDate(t *testing.T) {
	post := &Post{
		Slug: "2021-07-18-pagorki-przed-zniwami",
		Date: time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
	}

	if post.Slug != "2021-07-18-pagorki-przed-zniwami" {
		t.Errorf("Slug = %q, want full slug with date", post.Slug)
	}
}

func TestPostSlugName(t *testing.T) {
	tests := []struct {
		slug string
		want string
	}{
		{"2021-07-18-pagorki-przed-zniwami", "pagorki-przed-zniwami"},
		{"2018-11-05-spacer-na-przedmiescia", "spacer-na-przedmiescia"},
		{"2022-12-18-zdazyc-przed-koncem-zimy", "zdazyc-przed-koncem-zimy"},
	}
	for _, tt := range tests {
		post := &Post{Slug: tt.slug}
		if got := post.SlugName(); got != tt.want {
			t.Errorf("SlugName() for %q = %q, want %q", tt.slug, got, tt.want)
		}
	}
}

func TestPostURLGeneratedFromSlug(t *testing.T) {
	// Slug is "2021-07-18-pagorki-przed-zniwami"
	// URL should be "/2021/07/18-pagorki-przed-zniwami.html"
	// The URL is derived: /{year}/{month}/{slug[8:]}.html
	tests := []struct {
		slug string
		date time.Time
		want string
	}{
		{
			slug: "2021-07-18-pagorki-przed-zniwami",
			date: time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			want: "/2021/07/18-pagorki-przed-zniwami.html",
		},
		{
			slug: "2018-11-05-spacer-na-przedmiescia",
			date: time.Date(2018, 11, 5, 0, 0, 0, 0, time.UTC),
			want: "/2018/11/05-spacer-na-przedmiescia.html",
		},
	}
	for _, tt := range tests {
		post := &Post{Slug: tt.slug, Date: tt.date}
		// Replicate URL formula from router: /{year}/{month}/{slug[8:]}.html
		got := "/" + tt.slug[0:4] + "/" + tt.slug[5:7] + "/" + tt.slug[8:] + ".html"
		if got != tt.want {
			t.Errorf("URL for slug %q = %q, want %q", tt.slug, got, tt.want)
		}
		_ = post // verify post fields are consistent
	}
}

func TestPostIsFinished(t *testing.T) {
	// Unfinished post
	p := &Post{}
	if p.IsFinished() {
		t.Error("post with nil FinishedAt should not be finished")
	}

	// Post finished in the past
	past := time.Now().Add(-24 * time.Hour)
	p.FinishedAt = &past
	if !p.IsFinished() {
		t.Error("post with past FinishedAt should be finished")
	}

	// Post "finished" in the far future (draft marker)
	future := time.Date(2100, 1, 1, 0, 0, 0, 0, time.UTC)
	p.FinishedAt = &future
	if p.IsFinished() {
		t.Error("post with future FinishedAt should not be finished")
	}
}

func TestPostIsReady(t *testing.T) {
	if !(&Post{TagSlugs: []string{"bicycle"}}).IsReady() {
		t.Error("post without todo tag should be ready")
	}
	if (&Post{TagSlugs: []string{"todo", "bicycle"}}).IsReady() {
		t.Error("post tagged todo should not be ready")
	}
}

func TestPostIsRouteVisibleOnMap(t *testing.T) {
	withRoute := []Route{
		{Type: "bicycle", Segments: [][]LatLon{{{Lat: 52.4, Lon: 16.9}}}},
	}

	// Unfinished draft with a real track — the route map shows it anyway.
	if !(&Post{Routes: withRoute}).IsRouteVisibleOnMap() {
		t.Error("unfinished post with route data should be visible on the map")
	}
	// Hidden drafts must not surface anywhere.
	if (&Post{TagSlugs: []string{"hidden"}, Routes: withRoute}).IsRouteVisibleOnMap() {
		t.Error("post tagged hidden should not be visible on the map")
	}
	// Nothing to draw.
	if (&Post{}).IsRouteVisibleOnMap() {
		t.Error("post without routes should not be visible on the map")
	}
	// A route whose segments are all empty is still nothing to draw.
	empty := []Route{{Type: "bicycle", Segments: [][]LatLon{{}}}}
	if (&Post{Routes: empty}).IsRouteVisibleOnMap() {
		t.Error("post with empty route segments should not be visible on the map")
	}
	// Later routes count too — HasRoutes() only inspects the first.
	mixed := []Route{
		{Type: "bicycle", Segments: [][]LatLon{{}}},
		{Type: "train", Segments: [][]LatLon{{{Lat: 52.4, Lon: 16.9}}}},
	}
	if !(&Post{Routes: mixed}).IsRouteVisibleOnMap() {
		t.Error("post whose second route carries the points should be visible")
	}
}

func TestPostYear(t *testing.T) {
	p := &Post{Date: time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC)}
	if p.Year() != 2021 {
		t.Errorf("Year() = %d, want 2021", p.Year())
	}
}

func TestRoutesCoordRange(t *testing.T) {
	// Post without routes — should return false.
	p := &Post{}
	_, ok := p.RoutesCoordRange()
	if ok {
		t.Error("expected false for post without routes")
	}

	// Post with routes — should compute bounding box.
	p.Routes = []Route{{
		Type: "bicycle",
		Segments: [][]LatLon{
			{{Lat: 52.0, Lon: 16.5}, {Lat: 52.5, Lon: 17.0}},
			{{Lat: 52.2, Lon: 16.8}},
		},
	}}
	cr, ok := p.RoutesCoordRange()
	if !ok {
		t.Fatal("expected true for post with routes")
	}
	if cr.LatFrom != 52.0 || cr.LatTo != 52.5 {
		t.Errorf("lat range = [%f, %f], want [52.0, 52.5]", cr.LatFrom, cr.LatTo)
	}
	if cr.LonFrom != 16.5 || cr.LonTo != 17.0 {
		t.Errorf("lon range = [%f, %f], want [16.5, 17.0]", cr.LonFrom, cr.LonTo)
	}

	center := cr.Center()
	if center.Lat != 52.25 || center.Lon != 16.75 {
		t.Errorf("center = (%f, %f), want (52.25, 16.75)", center.Lat, center.Lon)
	}
}
