package model

import "math"

// Idea represents a trip idea loaded from YAML config.
type Idea struct {
	Slug      string   `yaml:"slug"`
	Link      string   `yaml:"link"`
	Distance  int      `yaml:"distance"`
	Elevation *int     `yaml:"elevation,omitempty"`
	DaysMin   int      `yaml:"days_min"`
	DaysNorm  int      `yaml:"days_normal"`
	Start     string   `yaml:"start"`
	Finish    string   `yaml:"finish"`
	Surfaces  []string `yaml:"surfaces"`
	Towns     []string `yaml:"towns"`
}

// TownsNotVisited returns the count of towns not yet visited by self-propelled trips.
func (idea *Idea) TownsNotVisited(visitedSlugs map[string]bool) int {
	count := 0
	for _, slug := range idea.Towns {
		if !visitedSlugs[slug] {
			count++
		}
	}
	return count
}

// TownsAlreadyVisited returns the count of towns already visited.
func (idea *Idea) TownsAlreadyVisited(visitedSlugs map[string]bool) int {
	count := 0
	for _, slug := range idea.Towns {
		if visitedSlugs[slug] {
			count++
		}
	}
	return count
}

// TimeCostStats computes time cost per new unvisited town.
// Matches Crystal's IdeaEntity#time_cost_stats_for_new_town.
type TimeCostStats struct {
	TimeCostRiding         int `json:"time_cost_riding"`
	TimeCostRidingAndTrain int `json:"time_cost_riding_and_train"`
	TimeCostWithSleeping   int `json:"time_cost_with_sleeping"`
}

// ComputeTimeCostStats calculates cost stats per unvisited town.
func (idea *Idea) ComputeTimeCostStats(visitedSlugs map[string]bool, totalTrainTime int) TimeCostStats {
	const realisticVelocity = 10 // km/h
	const maxPerDayRideTime = 8  // hours

	notVisited := idea.TownsNotVisited(visitedSlugs)
	if notVisited == 0 {
		return TimeCostStats{
			TimeCostRiding:         100,
			TimeCostRidingAndTrain: 100,
			TimeCostWithSleeping:   100,
		}
	}

	realisticRideTime := float64(idea.Distance) / float64(realisticVelocity)

	// Sleep/rest time: for multi-day rides, add rest hours per extra day
	sleepAndRestTime := 0.0
	if realisticRideTime > float64(maxPerDayRideTime) {
		daysRiding := math.Ceil(realisticRideTime / float64(maxPerDayRideTime))
		sleepAndRestTime = (daysRiding - 1) * float64(24-maxPerDayRideTime)
	}

	totalTime := realisticRideTime + sleepAndRestTime + float64(totalTrainTime)

	nv := float64(notVisited)
	return TimeCostStats{
		TimeCostRiding:         int(math.Ceil(realisticRideTime / nv)),
		TimeCostRidingAndTrain: int(math.Ceil((realisticRideTime + float64(totalTrainTime)) / nv)),
		TimeCostWithSleeping:   int(math.Ceil(totalTime / nv)),
	}
}

// DirectionBearing calculates bearing in degrees from station A to station B.
func DirectionBearing(lat1, lon1, lat2, lon2 float64) float64 {
	dLon := (lon2 - lon1) * math.Pi / 180.0
	lat1R := lat1 * math.Pi / 180.0
	lat2R := lat2 * math.Pi / 180.0

	y := math.Sin(dLon) * math.Cos(lat2R)
	x := math.Cos(lat1R)*math.Sin(lat2R) - math.Sin(lat1R)*math.Cos(lat2R)*math.Cos(dLon)

	bearing := math.Atan2(y, x) * 180.0 / math.Pi
	return math.Mod(bearing+360.0, 360.0)
}

// CompassNormalized returns a Polish direction label for a bearing.
// Matches Crystal's compass_normalized (mod 180, 8 segments).
func CompassNormalized(bearing float64) string {
	normalized := math.Mod(bearing, 180.0)

	points := []string{
		"000 - północny", "022 - północny lekko wschód", "045 - północny wschód", "067 - wschód lekko północ",
		"090 - wschód-zachód", "112 - zachód lekko północ", "135 - północny zachód", "157 - północ lekko zachód",
	}

	b := math.Mod(math.Mod(normalized, 360.0)+360.0, 360.0)
	segSize := 360.0 / float64(len(points))
	idx := int(math.Floor((b+segSize/2.0)/segSize)) % len(points)

	return points[idx]
}
