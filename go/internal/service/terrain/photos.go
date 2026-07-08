package terrain

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/disintegration/imaging"

	"odkrywajac/internal/model"
)

// Photo-pin sizing (screen pixels — the photos variant is rendered at the
// screen/article resolution, which is what the JSON hotspots refer to).
const (
	photoPinW    = 58
	photoPinH    = 44
	photoPinPad  = 2  // white frame thickness
	maxPhotoPins = 30 // cap so dense trips don't turn into a wall of thumbnails
)

// photoHotspot is one placed thumbnail's clickable area (pixels in the screen
// image) plus the full-size image URL and caption, for a frontend overlay.
type photoHotspot struct {
	X       int    `json:"x"`
	Y       int    `json:"y"`
	W       int    `json:"w"`
	H       int    `json:"h"`
	URL     string `json:"url"`
	Caption string `json:"caption,omitempty"`
}

// photosRef is the JSON sidecar for the photo map: georeference plus the photo
// hotspots. A frontend overlays transparent clickable areas at these rects
// (→ open the full image / show a tooltip) on top of the static PNG.
type photosRef struct {
	Zoom   int `json:"zoom"`
	Bounds struct {
		South float64 `json:"south"`
		West  float64 `json:"west"`
		North float64 `json:"north"`
		East  float64 `json:"east"`
	} `json:"bounds"`
	Size   [2]int         `json:"size"` // pixel size the hotspots refer to
	Photos []photoHotspot `json:"photos"`
}

// drawPhotoPins bakes GPS photo thumbnails (Panoramio-style) onto the image at
// their locations and returns the clickable hotspots. Thumbnails are read from
// the already-processed image files under outputDir. Photos are placed greedily
// by priority (timeline, then points) and skipped when they'd overlap one
// already placed, so the map stays legible.
func drawPhotoPins(img *image.RGBA, post *model.Post, pr projector, outputDir string) []photoHotspot {
	var photos []*model.Photo
	for _, p := range post.PublishedPhotos {
		if p.HasGPS() {
			photos = append(photos, p)
		}
	}
	sort.SliceStable(photos, func(i, j int) bool {
		if photos[i].IsTimeline != photos[j].IsTimeline {
			return photos[i].IsTimeline // timeline photos first
		}
		return photos[i].Points > photos[j].Points
	})

	year := post.Date.Year()
	var placed []labelBox
	var hotspots []photoHotspot
	for _, p := range photos {
		if len(hotspots) >= maxPhotoPins {
			break
		}
		x, y := pr.project(*p.Exif.Lat, *p.Exif.Lon)
		x0 := clampF(x-photoPinW/2, 0, pr.width-photoPinW)
		y0 := clampF(y-photoPinH/2, 0, pr.height-photoPinH)
		box := labelBox{x0 - photoPinPad, y0 - photoPinPad, x0 + photoPinW + photoPinPad, y0 + photoPinH + photoPinPad}
		if overlapsAny(box, placed) {
			continue
		}
		thumb := loadThumb(outputDir, post, p, year)
		if thumb == nil {
			continue
		}
		placed = append(placed, box)

		ix, iy := int(x0), int(y0)
		// White frame, then the cropped thumbnail on top.
		draw.Draw(img, image.Rect(ix-photoPinPad, iy-photoPinPad, ix+photoPinW+photoPinPad, iy+photoPinH+photoPinPad),
			image.NewUniform(color.White), image.Point{}, draw.Src)
		filled := imaging.Fill(thumb, photoPinW, photoPinH, imaging.Center, imaging.Lanczos)
		draw.Draw(img, image.Rect(ix, iy, ix+photoPinW, iy+photoPinH), filled, image.Point{}, draw.Over)

		hotspots = append(hotspots, photoHotspot{
			X: ix, Y: iy, W: photoPinW, H: photoPinH,
			URL:     fmt.Sprintf("/images/%d/%s/%s", year, post.Slug, p.ImageFilename),
			Caption: p.Desc,
		})
	}
	return hotspots
}

// loadThumb opens a photo's processed thumbnail from the output tree, or nil if
// it isn't there.
func loadThumb(outputDir string, post *model.Post, photo *model.Photo, year int) image.Image {
	nameNoExt := photo.ImageFilename
	if dot := strings.LastIndex(nameNoExt, "."); dot > 0 {
		nameNoExt = nameNoExt[:dot]
	}
	name := fmt.Sprintf("%s_%s_thumbnail.jpg", post.Slug, nameNoExt)
	path := filepath.Join(outputDir, "images", "processed",
		fmt.Sprintf("%d", year), fmt.Sprintf("%02d", int(post.Date.Month())), name)
	img, err := imaging.Open(path)
	if err != nil {
		return nil
	}
	return img
}

// writePhotosJSON writes the photo map's hotspot sidecar.
func writePhotosJSON(path string, zoom int, south, north, west, east float64, w, h int, hotspots []photoHotspot) error {
	var r photosRef
	r.Zoom = zoom
	r.Bounds.South, r.Bounds.North = south, north
	r.Bounds.West, r.Bounds.East = west, east
	r.Size = [2]int{w, h}
	r.Photos = hotspots
	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal photos json: %w", err)
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return fmt.Errorf("write photos json: %w", err)
	}
	return nil
}

// clampF clamps v to [lo, hi].
func clampF(v, lo, hi float64) float64 {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// overlapsAny reports whether box overlaps any already-placed box.
func overlapsAny(box labelBox, placed []labelBox) bool {
	for _, p := range placed {
		if box.overlaps(p) {
			return true
		}
	}
	return false
}
