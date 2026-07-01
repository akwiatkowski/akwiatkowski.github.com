// Package weather fetches historical weather data for a given location and time.
package weather

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// Data holds weather observations for a specific time.
type Data struct {
	Temperature   float64 // Celsius
	Precipitation float64 // mm
	WindSpeed     float64 // km/h
	CloudCover    int     // %
	IsDay         bool
}

// Client fetches weather from Open-Meteo's free API (no API key required).
type Client struct {
	BaseURL string
	Client  *http.Client
}

// NewClient creates a default weather client.
func NewClient() *Client {
	return &Client{
		BaseURL: "https://archive-api.open-meteo.com/v1/archive",
		Client:  &http.Client{Timeout: 10 * time.Second},
	}
}

// Fetch retrieves weather data for the given coordinates and date.
// It returns the closest hourly observation to the provided time.
func (c *Client) Fetch(lat, lon float64, t time.Time) (*Data, error) {
	dateStr := t.Format("2006-01-02")

	u, err := url.Parse(c.BaseURL)
	if err != nil {
		return nil, err
	}

	q := u.Query()
	q.Set("latitude", fmt.Sprintf("%.4f", lat))
	q.Set("longitude", fmt.Sprintf("%.4f", lon))
	q.Set("start_date", dateStr)
	q.Set("end_date", dateStr)
	q.Set("hourly", "temperature_2m,precipitation,cloudcover,windspeed_10m,is_day")
	q.Set("timezone", "auto")
	u.RawQuery = q.Encode()

	resp, err := c.Client.Get(u.String())
	if err != nil {
		return nil, fmt.Errorf("weather API request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("weather API returned %s", resp.Status)
	}

	var result apiResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode weather response: %w", err)
	}

	if len(result.Hourly.Time) == 0 {
		return nil, fmt.Errorf("no hourly data returned")
	}

	// Find the closest hour
	targetHour := t.Hour()
	bestIdx := 0
	bestDiff := 24
	for i, hourStr := range result.Hourly.Time {
		hourTime, err := time.Parse("2006-01-02T15:04", hourStr)
		if err != nil {
			continue
		}
		diff := abs(hourTime.Hour() - targetHour)
		if diff < bestDiff {
			bestDiff = diff
			bestIdx = i
		}
	}

	return &Data{
		Temperature:   result.Hourly.Temperature[bestIdx],
		Precipitation: result.Hourly.Precipitation[bestIdx],
		WindSpeed:     result.Hourly.WindSpeed[bestIdx],
		CloudCover:    result.Hourly.CloudCover[bestIdx],
		IsDay:         result.Hourly.IsDay[bestIdx] == 1,
	}, nil
}

type apiResponse struct {
	Hourly struct {
		Time          []string  `json:"time"`
		Temperature   []float64 `json:"temperature_2m"`
		Precipitation []float64 `json:"precipitation"`
		CloudCover    []int     `json:"cloudcover"`
		WindSpeed     []float64 `json:"windspeed_10m"`
		IsDay         []int     `json:"is_day"`
	} `json:"hourly"`
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
