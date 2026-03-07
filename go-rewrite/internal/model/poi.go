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

// TransportPOI is a bus/transit point of interest.
type TransportPOI struct {
	CommuneSlug string  `yaml:"commune_slug"`
	Name        string  `yaml:"name"`
	Major       bool    `yaml:"major"`
	TimeCost    int     `yaml:"time_cost"`
	Lat         float64 `yaml:"lat"`
	Lon         float64 `yaml:"lon"`
}
