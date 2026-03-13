package model

// TrainStation is a station with travel time distances to major cities.
type TrainStation struct {
	Name         string             `yaml:"name"`
	Lat          float64            `yaml:"lat"`
	Lon          float64            `yaml:"lon"`
	TimeDistance map[string]float64 `yaml:"time_distance"`
}

// PoznanTimeDistance returns the travel time from Poznań in hours.
func (s *TrainStation) PoznanTimeDistance() float64 {
	if d, ok := s.TimeDistance["Poznań"]; ok {
		return d
	}
	return 0
}

