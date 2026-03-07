package views

import "time"

// YearReportData holds all computed data for a year report page.
type YearReportData struct {
	Year          int
	AllYears      []int
	PostCount     int
	TotalDistance  int
	TotalTime     int
	BicycleCount  int
	HikeCount     int
	NewTownsCount int
	Months        [12]MonthStats
	MaxMonthDist  float64

	TagBreakdown []TagCount

	LongestTrip      float64
	LongestTripTitle string
	LongestTripURL   string
	IsLongestAllTime bool

	MostActiveMonth     string
	MostActiveMonthDist float64
	IsMostActiveAllTime bool

	MostPostsYear    int
	MostPostsCount   int
	IsPostRecordYear bool

	PrevYearDistance int
	PrevYearTime    int

	PhotoOfYearURL     string
	PhotoOfYearAVIF    string
	PhotoOfYearTitle   string
	PhotoOfYearPostURL string

	RouteJSON string
	HasRoutes bool

	Voivodeships   []VoivodeshipLink
	YearReportURLs []YearReportLink
}

// MonthStats holds aggregated stats for one month in a year report.
type MonthStats struct {
	Month          int
	Distance       float64
	BicycleDistance float64
	HikeDistance    float64
	TimeSpent      float64
	PostCount      int
}

// TagCount holds a tag name and its post count.
type TagCount struct {
	Name  string
	Count int
}

// VoivodeshipLink holds name and URL for a voivodeship.
type VoivodeshipLink struct {
	Name string
	URL  string
}

// YearReportLink holds year and URL for year navigation.
type YearReportLink struct {
	Year      int
	URL       string
	IsCurrent bool
}

// BurnoutMonth holds month-over-month comparison data.
type BurnoutMonth struct {
	Date                      time.Time
	Distance                  int
	DistanceLastYear          *int
	DistanceChange            *int
	DistanceChangePercent     *int
	DistanceAvg               *int
	DistanceAvgChange         *int
	DistanceAvgChangePercent  *int
	TimeSpent                 int
	TimeSpentLastYear         *int
	TimeSpentChange           *int
	TimeSpentChangePercent    *int
	TimeSpentAvg              *int
	TimeSpentAvgChange        *int
	TimeSpentAvgChangePercent *int
}

// BurnoutData holds all data for the burnout stats page.
type BurnoutData struct {
	Months     []BurnoutMonth
	MaxDistance int
	MaxTime    int
}

// TownsHistoryGroup holds towns for one voivodeship.
type TownsHistoryGroup struct {
	VoivodeshipName string
	VoivodeshipURL  string
	Towns           []TownHistoryEntry
}

// TownHistoryEntry holds one town's first visit data.
type TownHistoryEntry struct {
	Name       string
	URL        string
	FirstVisit time.Time
}

// TownsHistoryData holds all data for the towns history page.
type TownsHistoryData struct {
	Groups     []TownsHistoryGroup
	TotalTowns int
}

// TimelineMonth holds data for one month in the towns timeline.
type TimelineMonth struct {
	Date            time.Time
	Label           string
	SelfTowns       []TimelineTown
	VehicleTowns    []TimelineTown
	CumulativeSelf  int
	CumulativeTotal int
	RevisitCount    int
}

// TimelineTown holds one town entry in the timeline.
type TimelineTown struct {
	Name    string
	URL     string
	Ordinal int
	IsSelf  bool
}

// TownsTimelineData holds all data for the towns timeline page.
type TownsTimelineData struct {
	Months []TimelineMonth
}

// GalleryIndexLink holds a link in the gallery index page.
type GalleryIndexLink struct {
	URL      string
	Name     string
	Category string
}

// POIEntry holds a single POI for the POIs page JSON.
type POIEntry struct {
	Name     string  `json:"name"`
	Lat      float64 `json:"lat"`
	Lon      float64 `json:"lon"`
	Type     string  `json:"type"`
	PhotoURL string  `json:"photo_url,omitempty"`
	PhotoAVIF string `json:"photo_url_avif,omitempty"`
	PostTitle string `json:"post_title,omitempty"`
	PostURL   string `json:"post_url,omitempty"`
	PhotoDesc string `json:"photo_desc,omitempty"`
}

// DebugTagStatsRow holds one row in the tag stats debug page.
type DebugTagStatsRow struct {
	PostTitle    string
	PostURL      string
	TotalPhotos  int
	TaggedPhotos int
	GoodPhotos   int
	BestPhotos   int
}
