package coverage

import (
	"testing"
	"time"

	"odkrywajac/internal/model"
)

// A coordinate well inside Poland; all test geometry clusters here so it lands
// in one predictable cell unless deliberately offset.
const (
	testLat = 52.40
	testLon = 16.90
)

func finishedPost() *model.Post {
	finished := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	return &model.Post{Slug: "p", FinishedAt: &finished}
}

func route(routeType string, lat, lon float64) model.Route {
	return model.Route{
		Type:     routeType,
		Segments: [][]model.LatLon{{{Lat: lat, Lon: lon}}},
	}
}

func photo(filename, camera string, lat, lon float64) *model.Photo {
	return &model.Photo{
		ImageFilename: filename,
		Exif:          &model.ExifData{Lat: &lat, Lon: &lon, CameraName: camera},
	}
}

func TestClassifyRoute(t *testing.T) {
	cases := []struct {
		routeType string
		self      bool
		hike      bool
		base      float64
	}{
		{"hike", true, true, ScoreHike},
		{"bicycle", true, false, ScoreBicycle},
		{"e-bike", true, false, ScoreBicycle},
		{"canoe", true, false, ScoreBicycle},
		{"train", false, false, ScoreTrain},
		{"car", false, false, ScoreOther},
		{"bus", false, false, ScoreOther},
		{"air", false, false, ScoreOther},
		{"something-new", false, false, ScoreOther},
	}
	for _, c := range cases {
		got := classifyRoute(c.routeType)
		if got.self != c.self || got.hike != c.hike || got.base != c.base {
			t.Errorf("classifyRoute(%q) = %+v, want self=%v hike=%v base=%v",
				c.routeType, got, c.self, c.hike, c.base)
		}
	}
}

func TestIsDrone(t *testing.T) {
	drones := []string{"FC1102", "FC3582", "FC4170", "L2D-20c", "L1D-20c", "Mavic 3", "DJI Air 3"}
	for _, name := range drones {
		if !isDrone(name) {
			t.Errorf("isDrone(%q) = false, want true", name)
		}
	}
	notDrones := []string{"", "E-M10MarkII", "ILCE-7M3", "iPhone 13 Pro", "Hero3-Black Edition", "PENTAX K-5", "OM-1"}
	for _, name := range notDrones {
		if isDrone(name) {
			t.Errorf("isDrone(%q) = true, want false", name)
		}
	}
}

func TestScoreGrid_BicycleBase(t *testing.T) {
	post := finishedPost()
	post.Routes = []model.Route{route("bicycle", testLat, testLon)}

	scores := ScoreGrid([]*model.Post{post})
	if got := scores.CellScore(testLat, testLon); got != ScoreBicycle {
		t.Errorf("bicycle cell score = %v, want %v", got, ScoreBicycle)
	}
}

func TestScoreGrid_HikeBeatsBicycleWithinPost(t *testing.T) {
	// One post with both a hike and a bicycle route through the same cell is a
	// single trip; the base is the highest mode (hike), no repeat bonus.
	post := finishedPost()
	post.Routes = []model.Route{
		route("bicycle", testLat, testLon),
		route("hike", testLat, testLon),
	}
	scores := ScoreGrid([]*model.Post{post})
	if got := scores.CellScore(testLat, testLon); got != ScoreHike {
		t.Errorf("hike+bicycle same cell score = %v, want %v", got, ScoreHike)
	}
}

func TestScoreGrid_RepeatSelfTrips(t *testing.T) {
	// Two separate posts, each a bicycle route through the same cell: base 70
	// plus one repeat-trip bonus.
	makePost := func(slug string) *model.Post {
		finished := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
		return &model.Post{
			Slug:       slug,
			FinishedAt: &finished,
			Routes:     []model.Route{route("bicycle", testLat, testLon)},
		}
	}
	scores := ScoreGrid([]*model.Post{makePost("a"), makePost("b")})
	want := ScoreBicycle + ScoreRepeatSelfTrip
	if got := scores.CellScore(testLat, testLon); got != want {
		t.Errorf("two bicycle trips score = %v, want %v", got, want)
	}
}

func TestScoreGrid_TrainOnly(t *testing.T) {
	post := finishedPost()
	post.Routes = []model.Route{route("train", testLat, testLon)}
	scores := ScoreGrid([]*model.Post{post})
	if got := scores.CellScore(testLat, testLon); got != ScoreTrain {
		t.Errorf("train cell score = %v, want %v", got, ScoreTrain)
	}
}

func TestScoreGrid_PhotoStacking(t *testing.T) {
	// 2 published + 1 unpublished photo, no route → 2*10 + 4 = 24.
	post := finishedPost()
	pub1 := photo("pub1.jpg", "OM-1", testLat, testLon)
	pub2 := photo("pub2.jpg", "OM-1", testLat, testLon)
	unpub := photo("unpub.jpg", "OM-1", testLat, testLon)
	post.PublishedPhotos = []*model.Photo{pub1, pub2}
	post.AllPhotos = []*model.Photo{pub1, pub2, unpub}

	scores := ScoreGrid([]*model.Post{post})
	want := 2*ScorePhotoPublished + ScorePhotoUnpublished
	if got := scores.CellScore(testLat, testLon); got != want {
		t.Errorf("photo-stacking score = %v, want %v", got, want)
	}
}

func TestScoreGrid_DroneBonus(t *testing.T) {
	// One published drone photo → 10 + 5 = 15, on top of the route base.
	post := finishedPost()
	post.Routes = []model.Route{route("bicycle", testLat, testLon)}
	drone := photo("aerial.jpg", "FC3582", testLat, testLon)
	post.PublishedPhotos = []*model.Photo{drone}
	post.AllPhotos = []*model.Photo{drone}

	scores := ScoreGrid([]*model.Post{post})
	want := ScoreBicycle + ScorePhotoPublished + ScorePhotoDrone
	if got := scores.CellScore(testLat, testLon); got != want {
		t.Errorf("drone-photo score = %v, want %v", got, want)
	}
}

func TestScoreGrid_PhotoOnlyMakesVisited(t *testing.T) {
	// No route at all — photos alone score the cell.
	post := finishedPost()
	p := photo("only.jpg", "OM-1", testLat, testLon)
	post.PublishedPhotos = []*model.Photo{p}
	post.AllPhotos = []*model.Photo{p}

	scores := ScoreGrid([]*model.Post{post})
	if got := scores.CellScore(testLat, testLon); got != ScorePhotoPublished {
		t.Errorf("photo-only score = %v, want %v", got, ScorePhotoPublished)
	}
}

func TestScoreGrid_Cap(t *testing.T) {
	post := finishedPost()
	post.Routes = []model.Route{route("hike", testLat, testLon)}
	var all []*model.Photo
	for i := 0; i < 20; i++ {
		p := photo(string(rune('a'+i))+".jpg", "FC3582", testLat, testLon)
		all = append(all, p)
	}
	post.PublishedPhotos = all
	post.AllPhotos = all

	scores := ScoreGrid([]*model.Post{post})
	if got := scores.CellScore(testLat, testLon); got != ScoreCap {
		t.Errorf("saturated cell score = %v, want cap %v", got, ScoreCap)
	}
}

func TestScoreGrid_UnfinishedPostPhotosAreUnpublished(t *testing.T) {
	// A photo listed as "published" in a not-yet-finished post is not on the
	// blog, so it only earns the unpublished bonus.
	post := &model.Post{Slug: "draft"} // no FinishedAt → IsFinished() == false
	p := photo("draft.jpg", "OM-1", testLat, testLon)
	post.PublishedPhotos = []*model.Photo{p}
	post.AllPhotos = []*model.Photo{p}

	scores := ScoreGrid([]*model.Post{post})
	if got := scores.CellScore(testLat, testLon); got != ScorePhotoUnpublished {
		t.Errorf("draft photo score = %v, want %v", got, ScorePhotoUnpublished)
	}
}

func TestAreaScore_AveragesOverBounds(t *testing.T) {
	// One scored cell inside a 3-lat x 1-lon-degree box that spans many empty
	// cells: the average must be well below the single cell's score.
	post := finishedPost()
	post.Routes = []model.Route{route("hike", testLat, testLon)}
	scores := ScoreGrid([]*model.Post{post})

	bounds := Bounds{MinLat: testLat - 0.2, MaxLat: testLat + 0.2, MinLon: testLon - 0.2, MaxLon: testLon + 0.2}
	area := scores.AreaScore(bounds)
	if area <= 0 {
		t.Fatalf("area score = %v, want > 0", area)
	}
	if area >= ScoreHike {
		t.Errorf("area score = %v, want well below single-cell %v (empty cells drag it down)", area, ScoreHike)
	}
}

func TestAreaScore_EmptyAreaIsZero(t *testing.T) {
	scores := ScoreGrid(nil)
	bounds := Bounds{MinLat: testLat, MaxLat: testLat + 0.1, MinLon: testLon, MaxLon: testLon + 0.1}
	if got := scores.AreaScore(bounds); got != 0 {
		t.Errorf("empty area score = %v, want 0", got)
	}
}
