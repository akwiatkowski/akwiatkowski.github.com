package loader

import (
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	"odkrywajac/internal/exif"
	"odkrywajac/internal/model"
)

// PopulatePublishedPhotos builds Photo objects for each post from its parsed
// PublishedPhotoRefs, enriches them with EXIF data from the cache, and computes
// quality points from photo tag scores. Must run after LoadPosts and before
// BuildSiteData, since many views read post.PublishedPhotos.
func PopulatePublishedPhotos(posts []*model.Post, exifCache *exif.Cache, photoTags []model.PhotoTag) {
	pointsBySlug := buildPhotoTagPoints(photoTags)

	for _, post := range posts {
		if len(post.PublishedPhotoRefs) == 0 {
			continue
		}

		exifByFilename := loadExifMap(exifCache, post.DateSlug())

		for _, ref := range post.PublishedPhotoRefs {
			photo := &model.Photo{
				ImageFilename: ref.Filename,
				PostSlug:      post.Slug,
				Desc:          ref.Caption,
				TagSlugs:      ref.TagSlugs,
				Points:        computePoints(ref.TagSlugs, pointsBySlug),
				IsHeader:      post.ImageFilename == ref.Filename,
				IsGallery:     hasSlug(ref.TagSlugs, "gallery") || hasSlug(ref.TagSlugs, "good") || hasSlug(ref.TagSlugs, "best"),
				IsTimeline:    hasSlug(ref.TagSlugs, "timeline"),
				Exif:          exifByFilename[ref.Filename],
			}
			post.PublishedPhotos = append(post.PublishedPhotos, photo)
		}
	}
}

// PopulateAllPhotos scans each post's image directory and builds AllPhotos,
// which is a superset of PublishedPhotos. Published photos keep their full
// metadata (caption, tags, points); non-published photos get EXIF data only.
// Must run after PopulatePublishedPhotos.
func PopulateAllPhotos(posts []*model.Post, imagesDir string, exifCache *exif.Cache) {
	for _, post := range posts {
		// Build a lookup of already-published filenames for this post.
		publishedByFilename := make(map[string]*model.Photo, len(post.PublishedPhotos))
		for _, photo := range post.PublishedPhotos {
			publishedByFilename[photo.ImageFilename] = photo
		}

		// Scan image directory for all photos belonging to this post.
		postImageDir := postImagesPath(imagesDir, post)
		allFilenames := listImageFiles(postImageDir)

		if len(allFilenames) == 0 && len(post.PublishedPhotos) == 0 {
			continue
		}

		// Load EXIF data for non-published photos.
		exifByFilename := loadExifMap(exifCache, post.DateSlug())

		var allPhotos []*model.Photo

		// Start with published photos (they have full metadata).
		allPhotos = append(allPhotos, post.PublishedPhotos...)
		publishedSet := make(map[string]bool, len(post.PublishedPhotos))
		for _, photo := range post.PublishedPhotos {
			publishedSet[photo.ImageFilename] = true
		}

		// Add non-published photos from the directory.
		for _, filename := range allFilenames {
			if publishedSet[filename] {
				continue
			}
			photo := &model.Photo{
				ImageFilename: filename,
				PostSlug:      post.Slug,
				Exif:          exifByFilename[filename],
			}
			allPhotos = append(allPhotos, photo)
		}

		post.AllPhotos = allPhotos
	}
}

// postImagesPath returns the filesystem path to a post's image directory.
// Convention: images/{year}/{date-slug}/ (e.g. images/2022/2022-12-18-zdazyc-przed-koncem-zimy/).
func postImagesPath(imagesDir string, post *model.Post) string {
	year := post.Date.Format("2006")
	dateSlug := post.DateSlug()
	return filepath.Join(imagesDir, year, dateSlug)
}

// listImageFiles returns sorted basenames of .jpg/.jpeg/.png files in a directory.
func listImageFiles(dir string) []string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		// Directory may not exist for posts without images — expected.
		return nil
	}

	var filenames []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		lower := strings.ToLower(entry.Name())
		if strings.HasSuffix(lower, ".jpg") || strings.HasSuffix(lower, ".jpeg") || strings.HasSuffix(lower, ".png") {
			filenames = append(filenames, entry.Name())
		}
	}
	return filenames
}

// buildPhotoTagPoints creates a slug → points lookup from the photo tags config.
func buildPhotoTagPoints(photoTags []model.PhotoTag) map[string]int {
	points := make(map[string]int, len(photoTags))
	for _, tag := range photoTags {
		if tag.Points > points[tag.Slug] {
			points[tag.Slug] = tag.Points
		}
	}
	return points
}

// computePoints sums the point values for all photo tag slugs on a photo.
func computePoints(tagSlugs []string, pointsBySlug map[string]int) int {
	total := 0
	for _, slug := range tagSlugs {
		total += pointsBySlug[slug]
	}
	return total
}

// loadExifMap loads the EXIF cache for a post, indexed by image filename.
// Returns an empty map if the cache doesn't exist or fails to load.
func loadExifMap(cache *exif.Cache, postSlug string) map[string]*model.ExifData {
	exifMap, err := cache.LoadMap(postSlug)
	if err != nil {
		// Cache may not exist for all posts — this is expected.
		slog.Debug("No EXIF cache for post", "post", postSlug, "err", err)
		return make(map[string]*model.ExifData)
	}
	return exifMap
}

func hasSlug(slugs []string, target string) bool {
	for _, s := range slugs {
		if s == target {
			return true
		}
	}
	return false
}
