package view

import (
	"testing"
	"time"

	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
)

func testSiteDataForGallery() *index.SiteData {
	fin := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	exifTime := time.Date(2021, 7, 18, 10, 0, 0, 0, time.UTC)
	fl := 50.0
	iso := 200
	exp := 1.0 / 125.0
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-test-post",
			Title:      "Test Post",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin,
			TagSlugs:   []string{"bicycle"},
			PublishedPhotos: []*model.Photo{
				{
					ImageFilename: "photo1.jpg",
					PostSlug:      "2021-07-18-test-post",
					Desc:          "A good photo",
					TagSlugs:      []string{"good", "landscape"},
					Points:        5,
					Exif: &model.ExifData{
						LensName:   "Olympus 12-100mm",
						CameraName: "E-M1 Mark II",
						FocalLength: &fl,
						ISO:         &iso,
						Exposure:    &exp,
						Time:        &exifTime,
					},
				},
				{
					ImageFilename: "photo2.jpg",
					PostSlug:      "2021-07-18-test-post",
					Desc:          "A best photo",
					TagSlugs:      []string{"best"},
					Points:        10,
					IsHeader:      true,
					Exif: &model.ExifData{
						LensName:   "Olympus 12-100mm",
						CameraName: "E-M1 Mark II",
						FocalLength: &fl,
						ISO:         &iso,
						Exposure:    &exp,
						Time:        &exifTime,
					},
				},
				{
					ImageFilename: "photo3.jpg",
					PostSlug:      "2021-07-18-test-post",
					Desc:          "Untagged photo",
					Points:        1,
				},
			},
		},
	}
	photoTags := []model.PhotoTag{
		{Slug: "good", SlugPl: "dobre", Title: "Dobre"},
		{Slug: "best", SlugPl: "najlepsze", Title: "Najlepsze"},
	}
	cfg := model.SiteConfig{Title: "Test"}
	return index.BuildSiteData(posts, nil, photoTags, nil, cfg, nil, nil)
}

func TestGalleryFillAlgorithm(t *testing.T) {
	data := testSiteDataForGallery()
	allPhotos := allPublishedPhotos(data)

	// Filter by "good" tag
	photos := galleryFillPhotos(allPhotos, []string{"good"}, false, 0)
	if len(photos) != 1 {
		t.Errorf("good tag filter: got %d photos, want 1", len(photos))
	}

	// Filter by "best" tag
	photos = galleryFillPhotos(allPhotos, []string{"best"}, false, 0)
	if len(photos) != 1 {
		t.Errorf("best tag filter: got %d photos, want 1", len(photos))
	}

	// Fill up to 3 from 1 matched
	photos = galleryFillPhotos(allPhotos, []string{"best"}, false, 3)
	if len(photos) != 3 {
		t.Errorf("fill to 3: got %d photos, want 3", len(photos))
	}
}

func TestGalleryFillWithHeaders(t *testing.T) {
	data := testSiteDataForGallery()
	allPhotos := allPublishedPhotos(data)

	// Include headers should add photo2 (is_header) even if not matching tag
	photos := galleryFillPhotos(allPhotos, []string{"landscape"}, true, 0)
	if len(photos) != 2 {
		t.Errorf("with headers: got %d photos, want 2", len(photos))
	}
}

func TestPhotosForLens(t *testing.T) {
	data := testSiteDataForGallery()
	allPhotos := allPublishedPhotos(data)

	photos := photosForLens(allPhotos, "Olympus 12-100mm")
	if len(photos) != 2 {
		t.Errorf("lens filter: got %d, want 2", len(photos))
	}

	photos = photosForLens(allPhotos, "Nonexistent")
	if len(photos) != 0 {
		t.Errorf("nonexistent lens: got %d, want 0", len(photos))
	}
}

func TestPhotosForCamera(t *testing.T) {
	data := testSiteDataForGallery()
	allPhotos := allPublishedPhotos(data)

	photos := photosForCamera(allPhotos, "E-M1 Mark II")
	if len(photos) != 2 {
		t.Errorf("camera filter: got %d, want 2", len(photos))
	}
}

func TestPhotosInFocalRange(t *testing.T) {
	data := testSiteDataForGallery()
	allPhotos := allPublishedPhotos(data)

	photos := photosInFocalRange(allPhotos, 40, 60)
	if len(photos) != 2 {
		t.Errorf("focal 40-60: got %d, want 2", len(photos))
	}

	photos = photosInFocalRange(allPhotos, 100, 200)
	if len(photos) != 0 {
		t.Errorf("focal 100-200: got %d, want 0", len(photos))
	}
}

func TestPhotosInISORange(t *testing.T) {
	data := testSiteDataForGallery()
	allPhotos := allPublishedPhotos(data)

	photos := photosInISORange(allPhotos, 100, 400)
	if len(photos) != 2 {
		t.Errorf("ISO 100-400: got %d, want 2", len(photos))
	}
}

func TestPhotosInExposureRange(t *testing.T) {
	data := testSiteDataForGallery()
	allPhotos := allPublishedPhotos(data)

	photos := photosInExposureRange(allPhotos, 1.0/500, 1.0/30)
	if len(photos) != 2 {
		t.Errorf("exposure 1/500-1/30: got %d, want 2", len(photos))
	}
}

func TestSanitizeSlug(t *testing.T) {
	cases := map[string]string{
		"Olympus 12-100mm f/4.0": "olympus-12-100mm-f-4.0",
		"E-M1 Mark II":          "e-m1-mark-ii",
		"Canon EF 50mm":         "canon-ef-50mm",
	}
	for input, want := range cases {
		got := sanitizeSlug(input)
		if got != want {
			t.Errorf("sanitizeSlug(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestGalleryIndexPage(t *testing.T) {
	data := testSiteDataForGallery()
	r := router.New("https://example.com")

	page := GalleryIndexPage(data, r, nil)
	if page.URL() != "/galeria.html" {
		t.Errorf("URL() = %q", page.URL())
	}
	if !page.AddToSitemap() {
		t.Error("gallery index should be in sitemap")
	}
}

func TestFocalLengthRanges(t *testing.T) {
	ranges := FocalLengthRanges()
	if len(ranges) == 0 {
		t.Fatal("no focal length ranges")
	}
	if ranges[0][0] != 16.0 {
		t.Errorf("first range starts at %f, want 16.0", ranges[0][0])
	}
	// Verify ranges are contiguous
	for i := 1; i < len(ranges); i++ {
		if ranges[i][0] != ranges[i-1][1] {
			t.Errorf("gap between ranges %d and %d", i-1, i)
		}
	}
}

func TestISODoubleRanges(t *testing.T) {
	ranges := ISODoubleRanges()
	if len(ranges) != 10 {
		t.Errorf("expected 10 ISO ranges, got %d", len(ranges))
	}
	for i := 1; i < len(ranges); i++ {
		if ranges[i][0] != ranges[i-1][1] {
			t.Errorf("gap between ranges %d and %d", i-1, i)
		}
	}
}

func TestExposureRanges(t *testing.T) {
	ranges := ExposureRanges()
	if len(ranges) != 8 {
		t.Errorf("expected 8 exposure ranges, got %d", len(ranges))
	}
}
