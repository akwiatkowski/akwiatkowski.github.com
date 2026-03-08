package e2e

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestProcessedImageExists(t *testing.T) {
	ts := setupServer(t)

	// Get homepage JSON to find a real card image URL
	resp, err := http.Get(ts.URL + "/jsons/homepage.json")
	if err != nil {
		t.Fatalf("GET /jsons/homepage.json failed: %v", err)
	}
	defer resp.Body.Close()

	var data struct {
		Posts []struct {
			CardImage string `json:"card_image_url"`
		} `json:"posts"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		t.Fatalf("JSON decode failed: %v", err)
	}

	if len(data.Posts) == 0 {
		t.Skip("no posts in homepage JSON")
	}

	cardURL := data.Posts[0].CardImage
	if cardURL == "" {
		t.Skip("first post has no card_image_url")
	}

	resp2, err := http.Get(ts.URL + cardURL)
	if err != nil {
		t.Fatalf("GET %s failed: %v", cardURL, err)
	}
	defer resp2.Body.Close()

	if resp2.StatusCode != 200 {
		t.Errorf("GET %s = %d, want 200", cardURL, resp2.StatusCode)
	}
}

func TestProcessedImageFormats(t *testing.T) {
	ts := setupServer(t)

	resp, err := http.Get(ts.URL + "/jsons/homepage.json")
	if err != nil {
		t.Fatalf("GET /jsons/homepage.json failed: %v", err)
	}
	defer resp.Body.Close()

	var data struct {
		Posts []struct {
			CardImage string `json:"card_image_url"`
			CardAVIF  string `json:"card_image_url_avif"`
		} `json:"posts"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		t.Fatalf("JSON decode failed: %v", err)
	}

	if len(data.Posts) == 0 {
		t.Skip("no posts in homepage JSON")
	}

	post := data.Posts[0]

	// Test JPEG variant
	if post.CardImage != "" {
		resp, err := http.Get(ts.URL + post.CardImage)
		if err != nil {
			t.Fatalf("GET %s failed: %v", post.CardImage, err)
		}
		resp.Body.Close()
		if resp.StatusCode != 200 {
			t.Errorf("JPEG card %s = %d, want 200", post.CardImage, resp.StatusCode)
		}
	}

	// Test AVIF variant
	if post.CardAVIF != "" {
		resp, err := http.Get(ts.URL + post.CardAVIF)
		if err != nil {
			t.Fatalf("GET %s failed: %v", post.CardAVIF, err)
		}
		resp.Body.Close()
		if resp.StatusCode != 200 {
			t.Errorf("AVIF card %s = %d, want 200", post.CardAVIF, resp.StatusCode)
		}
	}
}

func TestRawImageExists(t *testing.T) {
	ts := setupServer(t)

	// Get homepage JSON for a post with photos
	resp, err := http.Get(ts.URL + "/jsons/homepage.json")
	if err != nil {
		t.Fatalf("GET /jsons/homepage.json failed: %v", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	var data struct {
		Posts []struct {
			CardImage string `json:"card_image_url"`
		} `json:"posts"`
	}
	if err := json.Unmarshal(body, &data); err != nil {
		t.Fatalf("JSON decode failed: %v", err)
	}

	if len(data.Posts) == 0 {
		t.Skip("no posts in homepage JSON")
	}

	// Extract year from a processed card URL to verify raw images directory exists
	// Card URL format: /images/processed/YYYY/MM/{date-slug}_{filename}_{size}.{format}
	cardURL := data.Posts[0].CardImage
	if cardURL == "" {
		t.Skip("first post has no card_image_url")
	}

	parts := strings.Split(strings.TrimPrefix(cardURL, "/images/processed/"), "/")
	if len(parts) < 3 {
		t.Skipf("unexpected card URL format: %s", cardURL)
	}
	year := parts[0]

	rawDirURL := "/images/" + year + "/"
	resp2, err := http.Get(ts.URL + rawDirURL)
	if err != nil {
		t.Fatalf("GET %s failed: %v", rawDirURL, err)
	}
	resp2.Body.Close()

	if resp2.StatusCode != 200 {
		t.Errorf("raw images dir %s = %d, want 200", rawDirURL, resp2.StatusCode)
	}
}
