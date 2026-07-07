// Package coverage scores how thoroughly the ground has been explored, by
// overlaying Poland with a fixed square grid and scoring each cell from the
// routes and photos that fall inside it. Area (powiat/voivodeship/…) scores
// are the average cell score over the area's bounding box.
//
// The model is intentionally about *depth*, not a binary "visited" flag: a
// powiat crossed once by train with a single photo scores far below one you
// have criss-crossed on a bike with dozens of photos. See ScoreGrid for the
// exact scoring rules and the exported constants for the tunable weights.
//
// The package is pure (no I/O) and independent of any renderer — the homepage
// coverage map is only its first consumer.
package coverage

import (
	"math"
	"regexp"
	"strings"

	"odkrywajac/internal/model"
)

// GridCellKm is the side length of one grid cell, in kilometers. 5 km is a
// deliberate first choice; it lives in a constant so it can be tuned (e.g. to
// 2 km) without touching the rest of the code.
const GridCellKm = 5.0

// Scoring weights (percentage points). All values come directly from the
// exploration model Olek specified — they are product decisions, not physical
// constants, and are meant to be tweaked.
const (
	// Base score for a cell, by the transport mode of a route passing through
	// it. When several modes touch one cell, the highest base wins.
	ScoreHike    = 80.0 // on foot — the most thorough way to see a place
	ScoreBicycle = 70.0 // bicycle / e-bike / other human-powered
	ScoreTrain   = 30.0 // passed through by rail
	ScoreOther   = 20.0 // car / bus / air / anything else motorized

	// Each *additional* self-powered trip (a distinct post whose bike/hike
	// route crosses the cell) beyond the first adds this much. Repeated visits
	// mean the place is better known.
	ScoreRepeatSelfTrip = 15.0

	// Per-photo bonuses (stack across every photo in the cell).
	ScorePhotoPublished   = 10.0 // photo published in a finished post
	ScorePhotoUnpublished = 4.0  // photo taken there but not published
	ScorePhotoDrone       = 5.0  // extra, added on top, for a drone shot

	// A cell can never exceed this. 100 = "fully explored, no reason to
	// return".
	ScoreCap = 100.0
)

// Poland's geographic extent, used as the grid origin so every consumer scores
// against the same cell lattice. Values are a generous bounding box of the
// country; points outside it simply never land in a cell.
const (
	polandMinLat = 49.0
	polandMinLon = 14.0
	// polandMidLat is the reference latitude for converting the east-west cell
	// size from kilometers to degrees of longitude (which shrink toward the
	// poles). Using one fixed value keeps cells ~square across the country.
	polandMidLat = 52.0
	// kmPerDegLat is the length of one degree of latitude in kilometers. It is
	// very nearly constant (~111.32 km) over Poland's small latitude span.
	kmPerDegLat = 111.32
)

// cell identifies one grid square by its integer row (north-south) and column
// (east-west) offset from the grid origin.
type cell struct {
	row int
	col int
}

// Grid maps geographic coordinates onto the fixed square lattice.
type Grid struct {
	degPerCellLat float64 // cell height in degrees of latitude
	degPerCellLon float64 // cell width in degrees of longitude
}

// NewGrid builds the grid for the given cell size in kilometers.
func NewGrid(cellKm float64) Grid {
	degLat := cellKm / kmPerDegLat
	// One degree of longitude spans kmPerDegLat*cos(latitude) km.
	degLon := cellKm / (kmPerDegLat * math.Cos(polandMidLat*math.Pi/180.0))
	return Grid{degPerCellLat: degLat, degPerCellLon: degLon}
}

// cellOf returns the cell containing the given coordinate.
func (g Grid) cellOf(lat, lon float64) cell {
	return cell{
		row: int(math.Floor((lat - polandMinLat) / g.degPerCellLat)),
		col: int(math.Floor((lon - polandMinLon) / g.degPerCellLon)),
	}
}

// Bounds is an axis-aligned lat/lon box. It mirrors model.BBox but is defined
// here so the package has no dependency on how areas store their extents.
type Bounds struct {
	MinLat, MaxLat float64
	MinLon, MaxLon float64
}

// BoundsFromBBox adapts a model.BBox to Bounds.
func BoundsFromBBox(b model.BBox) Bounds {
	return Bounds{MinLat: b.South, MaxLat: b.North, MinLon: b.West, MaxLon: b.East}
}

// routeClass is the scoring interpretation of one route's transport mode.
type routeClass struct {
	self bool    // human-powered (bike/hike/…)
	hike bool    // specifically on foot (highest base)
	base float64 // base score contributed for a non-repeat visit
}

// classifyRoute maps a coords_type string to its scoring class.
func classifyRoute(routeType string) routeClass {
	switch strings.ToLower(strings.TrimSpace(routeType)) {
	case "hike":
		return routeClass{self: true, hike: true, base: ScoreHike}
	case "bicycle", "e-bike", "ebike", "canoe":
		// Canoe is human-powered too; grouped with the bicycle tier.
		return routeClass{self: true, base: ScoreBicycle}
	case "train":
		return routeClass{base: ScoreTrain}
	default:
		// car, bus, ev, air, or anything unrecognized — motorized transit.
		return routeClass{base: ScoreOther}
	}
}

// djiFCPattern matches DJI's "FCxxxx" camera model codes (e.g. FC1102, FC3582,
// FC4170), which identify drone cameras.
var djiFCPattern = regexp.MustCompile(`^FC\d`)

// isDrone reports whether an EXIF camera name belongs to a drone. It matches
// DJI's FCxxxx model codes and the L1D/L2D Hasselblad gimbal cameras (Mavic 2
// Pro / Mavic 3), plus obvious brand keywords for forward compatibility.
func isDrone(cameraName string) bool {
	if cameraName == "" {
		return false
	}
	if djiFCPattern.MatchString(cameraName) {
		return true
	}
	if strings.HasPrefix(cameraName, "L1D") || strings.HasPrefix(cameraName, "L2D") {
		return true
	}
	upper := strings.ToUpper(cameraName)
	for _, keyword := range []string{"MAVIC", "PHANTOM", "DJI"} {
		if strings.Contains(upper, keyword) {
			return true
		}
	}
	return false
}

// cellAccumulator gathers the raw evidence for one cell before it is reduced
// to a final score.
type cellAccumulator struct {
	selfTrips  int     // distinct posts with a bike/hike route through the cell
	hasHike    bool    // at least one of those trips was on foot
	otherMax   float64 // best base among non-self routes (train/car/…)
	photoBonus float64 // summed per-photo bonuses
}

// Scores holds the computed per-cell scores and answers area queries.
type Scores struct {
	grid  Grid
	cells map[cell]float64
}

// ScoreGrid computes cell scores from the given posts. The caller decides which
// posts to include; the homepage passes finished posts only, so that "published
// photo" (+ScorePhotoPublished) means a photo actually on the blog and drafts
// never leak onto the public map.
//
// Per cell the score is built as:
//   - base: the single highest route-mode base touching the cell
//     (hike > bicycle > train > other);
//   - +ScoreRepeatSelfTrip for each self-powered trip beyond the first;
//   - + per-photo bonuses, summed over every GPS-tagged photo in the cell
//     (published/unpublished, plus a drone extra);
//   - capped at ScoreCap.
//
// A cell needs no route at all: enough photos alone can mark it explored.
func ScoreGrid(posts []*model.Post) *Scores {
	grid := NewGrid(GridCellKm)
	acc := make(map[cell]*cellAccumulator)

	at := func(c cell) *cellAccumulator {
		a := acc[c]
		if a == nil {
			a = &cellAccumulator{}
			acc[c] = a
		}
		return a
	}

	for _, post := range posts {
		scoreRoutes(grid, at, post)
		scorePhotos(grid, at, post)
	}

	cells := make(map[cell]float64, len(acc))
	for c, a := range acc {
		cells[c] = finalizeCell(a)
	}
	return &Scores{grid: grid, cells: cells}
}

// perPostCell tracks, within one post, the strongest evidence seen for a cell,
// so that a single post touching a cell many times counts as one trip.
type perPostCell struct {
	self     bool
	hike     bool
	otherMax float64
}

// scoreRoutes folds one post's routes into the accumulator, deduplicating cells
// per post so repeated points in the same cell do not inflate the trip count.
func scoreRoutes(grid Grid, at func(cell) *cellAccumulator, post *model.Post) {
	postCells := make(map[cell]*perPostCell)
	for _, route := range post.Routes {
		class := classifyRoute(route.Type)
		for _, segment := range route.Segments {
			for _, point := range segment {
				c := grid.cellOf(point.Lat, point.Lon)
				pc := postCells[c]
				if pc == nil {
					pc = &perPostCell{}
					postCells[c] = pc
				}
				if class.self {
					pc.self = true
					pc.hike = pc.hike || class.hike
				} else if class.base > pc.otherMax {
					pc.otherMax = class.base
				}
			}
		}
	}
	for c, pc := range postCells {
		a := at(c)
		if pc.self {
			a.selfTrips++
			a.hasHike = a.hasHike || pc.hike
		} else if pc.otherMax > a.otherMax {
			a.otherMax = pc.otherMax
		}
	}
}

// scorePhotos folds one post's photos into the accumulator. Every GPS-tagged
// photo contributes: +ScorePhotoPublished if it is a published photo of a
// finished post, else +ScorePhotoUnpublished, plus +ScorePhotoDrone for drone
// shots. Bonuses stack across photos.
func scorePhotos(grid Grid, at func(cell) *cellAccumulator, post *model.Post) {
	publishedNames := make(map[string]bool, len(post.PublishedPhotos))
	for _, photo := range post.PublishedPhotos {
		publishedNames[photo.ImageFilename] = true
	}

	// Iterate the union of AllPhotos and PublishedPhotos by filename, so we
	// count every photo even if one of the two slices is unexpectedly empty.
	seen := make(map[string]bool)
	consider := func(photo *model.Photo) {
		if seen[photo.ImageFilename] || !photo.HasGPS() {
			return
		}
		seen[photo.ImageFilename] = true

		c := grid.cellOf(*photo.Exif.Lat, *photo.Exif.Lon)
		bonus := ScorePhotoUnpublished
		if post.IsFinished() && publishedNames[photo.ImageFilename] {
			bonus = ScorePhotoPublished
		}
		if isDrone(photo.Exif.CameraName) {
			bonus += ScorePhotoDrone
		}
		at(c).photoBonus += bonus
	}

	for _, photo := range post.AllPhotos {
		consider(photo)
	}
	for _, photo := range post.PublishedPhotos {
		consider(photo)
	}
}

// finalizeCell reduces accumulated evidence to a single capped score.
func finalizeCell(a *cellAccumulator) float64 {
	var score float64
	if a.selfTrips >= 1 {
		base := ScoreBicycle
		if a.hasHike {
			base = ScoreHike
		}
		score = base + float64(a.selfTrips-1)*ScoreRepeatSelfTrip
	} else {
		score = a.otherMax
	}
	score += a.photoBonus
	if score > ScoreCap {
		score = ScoreCap
	}
	return score
}

// CellScore returns the score (0–100) of the cell containing a coordinate.
func (s *Scores) CellScore(lat, lon float64) float64 {
	return s.cells[s.grid.cellOf(lat, lon)]
}

// AreaScore returns the mean cell score over every cell whose position falls in
// the given bounds, counting unscored cells as 0. Averaging over the whole box
// (not just touched cells) is what makes the score reflect how much of the area
// remains unexplored — a thin route through a large powiat yields a low mean.
// Using the bounding box rather than the exact polygon is a deliberate
// simplification.
func (s *Scores) AreaScore(b Bounds) float64 {
	minCell := s.grid.cellOf(b.MinLat, b.MinLon)
	maxCell := s.grid.cellOf(b.MaxLat, b.MaxLon)

	var sum float64
	var count int
	for row := minCell.row; row <= maxCell.row; row++ {
		for col := minCell.col; col <= maxCell.col; col++ {
			sum += s.cells[cell{row: row, col: col}]
			count++
		}
	}
	if count == 0 {
		return 0
	}
	return sum / float64(count)
}
