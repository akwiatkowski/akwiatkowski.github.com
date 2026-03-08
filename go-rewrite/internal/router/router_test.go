package router

import (
	"testing"
	"time"

	"odkrywajac/internal/model"
)

func newRouter() *Router {
	return New("https://odkrywajacpolske.pl")
}

func TestAreaShowURL(t *testing.T) {
	r := newRouter()
	tests := []struct {
		area *model.Area
		want string
	}{
		{&model.Area{Slug: "pobiedziska", Type: model.AreaTypeTown}, "/gmina/pobiedziska.html"},
		{&model.Area{Slug: "poznan", Type: model.AreaTypeCounty}, "/powiat/poznan.html"},
		{&model.Area{Slug: "wielkopolskie", Type: model.AreaTypeVoivodeship}, "/wojewodztwo/wielkopolskie.html"},
		{&model.Area{Slug: "pojezierze-gniezninskie", Type: model.AreaTypeMesoRegion}, "/mezoregion/pojezierze-gniezninskie.html"},
		{&model.Area{Slug: "pojezierze-wielkopolskie", Type: model.AreaTypeMacroRegion}, "/makroregion/pojezierze-wielkopolskie.html"},
	}
	for _, tt := range tests {
		if got := r.AreaShowURL(tt.area); got != tt.want {
			t.Errorf("AreaShowURL(%s:%s) = %q, want %q", tt.area.Type, tt.area.Slug, got, tt.want)
		}
	}
}

func TestAreaPostListURL(t *testing.T) {
	r := newRouter()
	tests := []struct {
		area *model.Area
		want string
	}{
		{&model.Area{Slug: "pobiedziska", Type: model.AreaTypeTown}, "/wpisy-dla/gminy/pobiedziska.html"},
		{&model.Area{Slug: "poznan", Type: model.AreaTypeCounty}, "/wpisy-dla/powiatu/poznan.html"},
		{&model.Area{Slug: "wielkopolskie", Type: model.AreaTypeVoivodeship}, "/wpisy-dla/wojewodztwa/wielkopolskie.html"},
		{&model.Area{Slug: "pojezierze", Type: model.AreaTypeMesoRegion}, "/wpisy-dla/regionu/pojezierze.html"},
		{&model.Area{Slug: "pojezierze", Type: model.AreaTypeMacroRegion}, "/wpisy-dla/obszaru/pojezierze.html"},
	}
	for _, tt := range tests {
		if got := r.AreaPostListURL(tt.area); got != tt.want {
			t.Errorf("AreaPostListURL(%s:%s) = %q, want %q", tt.area.Type, tt.area.Slug, got, tt.want)
		}
	}
}

func TestAreaGalleryURL(t *testing.T) {
	r := newRouter()
	area := &model.Area{Slug: "pobiedziska", Type: model.AreaTypeTown}
	want := "/galeria/gminy/pobiedziska.html"
	if got := r.AreaGalleryURL(area); got != want {
		t.Errorf("AreaGalleryURL() = %q, want %q", got, want)
	}
}

func TestAreaLinkURL(t *testing.T) {
	area := &model.Area{Slug: "pobiedziska", Type: model.AreaTypeTown}

	// Default: show
	r := newRouter()
	if got := r.AreaLinkURL(area); got != "/gmina/pobiedziska.html" {
		t.Errorf("AreaLinkURL(Show) = %q", got)
	}

	// Post list
	r.AreaLinkTarget = AreaLinkPostList
	if got := r.AreaLinkURL(area); got != "/wpisy-dla/gminy/pobiedziska.html" {
		t.Errorf("AreaLinkURL(PostList) = %q", got)
	}

	// Gallery
	r.AreaLinkTarget = AreaLinkGallery
	if got := r.AreaLinkURL(area); got != "/galeria/gminy/pobiedziska.html" {
		t.Errorf("AreaLinkURL(Gallery) = %q", got)
	}
}

func TestTagURLs(t *testing.T) {
	r := newRouter()
	tag := &model.Tag{Slug: "bicycle", SlugPl: "rowerem"}

	tests := []struct {
		name string
		got  string
		want string
	}{
		{"TagShowURL", r.TagShowURL(tag), "/tag/rowerem.html"},
		{"TagPostListURL", r.TagPostListURL(tag), "/wpisy-dla/tagu/rowerem.html"},
		{"TagGalleryURL", r.TagGalleryURL(tag), "/galeria/tag/rowerem.html"},
	}
	for _, tt := range tests {
		if tt.got != tt.want {
			t.Errorf("%s() = %q, want %q", tt.name, tt.got, tt.want)
		}
	}
}

func TestTagLinkURL(t *testing.T) {
	tag := &model.Tag{Slug: "hike", SlugPl: "pieszo"}

	r := newRouter()
	if got := r.TagLinkURL(tag); got != "/tag/pieszo.html" {
		t.Errorf("TagLinkURL(Show) = %q", got)
	}

	r.TagLinkTarget = TagLinkGallery
	if got := r.TagLinkURL(tag); got != "/galeria/tag/pieszo.html" {
		t.Errorf("TagLinkURL(Gallery) = %q", got)
	}
}

func TestPostURL(t *testing.T) {
	r := newRouter()
	post := &model.Post{
		Slug: "pagorki-przed-zniwami",
		Date: time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
	}
	want := "/2021/07/18-pagorki-przed-zniwami.html"
	if got := r.PostURL(post); got != want {
		t.Errorf("PostURL() = %q, want %q", got, want)
	}
}

func TestPostGalleryURL(t *testing.T) {
	r := newRouter()
	post := &model.Post{
		Slug: "pagorki",
		Date: time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
	}
	want := "/2021/07/pagorki/galeria.html"
	if got := r.PostGalleryURL(post); got != want {
		t.Errorf("PostGalleryURL() = %q, want %q", got, want)
	}
}

func TestPostGalleryStatsURL(t *testing.T) {
	r := newRouter()
	post := &model.Post{
		Slug: "pagorki",
		Date: time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
	}
	want := "/2021/07/pagorki/galeria-statystyki.html"
	if got := r.PostGalleryStatsURL(post); got != want {
		t.Errorf("PostGalleryStatsURL() = %q, want %q", got, want)
	}
}

func TestProcessedImageURL(t *testing.T) {
	r := newRouter()
	post := &model.Post{
		Slug: "pagorki",
		Date: time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
	}

	// Extension is stripped, date-slug is used
	got := r.ProcessedImageURL(post, "header.jpg", "grid", "avif")
	want := "/images/processed/2021/07/2021-07-18-pagorki_header_grid.avif"
	if got != want {
		t.Errorf("ProcessedImageURL() = %q, want %q", got, want)
	}

	// Realistic filename with timestamp
	got2 := r.ProcessedImageURL(post, "2021_07_18__11_18__7189980.jpg", "card", "jpg")
	want2 := "/images/processed/2021/07/2021-07-18-pagorki_2021_07_18__11_18__7189980_card.jpg"
	if got2 != want2 {
		t.Errorf("ProcessedImageURL() = %q, want %q", got2, want2)
	}
}

func TestStaticURLs(t *testing.T) {
	r := newRouter()
	tests := []struct {
		name string
		got  string
		want string
	}{
		{"HomeURL", r.HomeURL(), "/"},
		{"MapURL", r.MapURL(), "/mapa_tras.html"},
		{"AboutURL", r.AboutURL(), "/o-mnie.html"},
		{"MoreURL", r.MoreURL(), "/wiecej.html"},
		{"YearReportURL", r.YearReportURL(2024), "/rok-2024.html"},
	}
	for _, tt := range tests {
		if tt.got != tt.want {
			t.Errorf("%s() = %q, want %q", tt.name, tt.got, tt.want)
		}
	}
}

func TestFeedURLs(t *testing.T) {
	r := newRouter()
	tests := []struct {
		name string
		got  string
		want string
	}{
		{"RSSURL", r.RSSURL(), "/feed.xml"},
		{"AtomURL", r.AtomURL(), "/feed_atom.xml"},
		{"SitemapURL", r.SitemapURL(), "/sitemap.xml"},
		{"RobotsURL", r.RobotsURL(), "/robots.txt"},
	}
	for _, tt := range tests {
		if tt.got != tt.want {
			t.Errorf("%s() = %q, want %q", tt.name, tt.got, tt.want)
		}
	}
}

func TestJSONEndpointURLs(t *testing.T) {
	r := newRouter()
	tests := []struct {
		name string
		got  string
		want string
	}{
		{"HomepageJSON", r.HomepageJSON(), "/jsons/homepage.json"},
		{"E2EJSON", r.E2EJSON(), "/jsons/e2e.json"},
		{"MapJSON", r.MapJSON(), "/jsons/map.json"},
		{"PhotosMapJSON", r.PhotosMapJSON(), "/jsons/photos_map.json"},
	}
	for _, tt := range tests {
		if tt.got != tt.want {
			t.Errorf("%s() = %q, want %q", tt.name, tt.got, tt.want)
		}
	}
}

func TestIndexURLs(t *testing.T) {
	r := newRouter()
	tests := []struct {
		name string
		got  string
		want string
	}{
		{"TagsIndexURL", r.TagsIndexURL(), "/tagi.html"},
		{"TownsIndexURL", r.TownsIndexURL(), "/gminy.html"},
		{"VoivodeshipsIndexURL", r.VoivodeshipsIndexURL(), "/wojewodztwa.html"},
		{"LandsIndexURL", r.LandsIndexURL(), "/krainy.html"},
		{"MesoRegionsIndexURL", r.MesoRegionsIndexURL(), "/regiony.html"},
		{"MacroRegionsIndexURL", r.MacroRegionsIndexURL(), "/obszary.html"},
	}
	for _, tt := range tests {
		if tt.got != tt.want {
			t.Errorf("%s() = %q, want %q", tt.name, tt.got, tt.want)
		}
	}
}

func TestCanonicalURL(t *testing.T) {
	r := newRouter()
	got := r.CanonicalURL("/gmina/pobiedziska.html")
	want := "https://odkrywajacpolske.pl/gmina/pobiedziska.html"
	if got != want {
		t.Errorf("CanonicalURL() = %q, want %q", got, want)
	}
}

func TestMonthZeroPadding(t *testing.T) {
	r := newRouter()
	post := &model.Post{
		Slug: "spacer",
		Date: time.Date(2018, 1, 5, 0, 0, 0, 0, time.UTC),
	}
	got := r.PostURL(post)
	want := "/2018/01/05-spacer.html"
	if got != want {
		t.Errorf("PostURL() = %q, want %q (month not zero-padded)", got, want)
	}
}
