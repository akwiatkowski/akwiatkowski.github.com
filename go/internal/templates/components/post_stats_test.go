package components_test

import (
	"testing"

	"odkrywajac/internal/templates/components"
	h "odkrywajac/internal/templates/htmltest"
)

func TestPostStats_RendersDistance(t *testing.T) {
	stats := components.PostStatsData{Distance: 42, TimeSpent: 0, Elevation: 0}
	out := h.Render(t, components.PostStats(stats))
	doc := h.Parse(t, out)

	distSpans := h.FindByClass(doc, "stat-distance")
	if len(distSpans) == 0 {
		t.Fatal("expected .stat-distance")
	}
	text := h.InnerText(distSpans[0])
	if text != "42km" {
		t.Errorf("expected '42km', got %q", text)
	}
}

func TestPostStats_RendersElevation(t *testing.T) {
	stats := components.PostStatsData{Distance: 0, Elevation: 350}
	out := h.Render(t, components.PostStats(stats))
	doc := h.Parse(t, out)

	elevSpans := h.FindByClass(doc, "stat-elevation")
	if len(elevSpans) == 0 {
		t.Fatal("expected .stat-elevation")
	}
	text := h.InnerText(elevSpans[0])
	if text != "350m" {
		t.Errorf("expected '350m', got %q", text)
	}
}

func TestPostStats_RendersTime(t *testing.T) {
	stats := components.PostStatsData{TimeSpent: 5}
	out := h.Render(t, components.PostStats(stats))
	doc := h.Parse(t, out)

	timeSpans := h.FindByClass(doc, "stat-time")
	if len(timeSpans) == 0 {
		t.Fatal("expected .stat-time")
	}
	text := h.InnerText(timeSpans[0])
	if text != "5h" {
		t.Errorf("expected '5h', got %q", text)
	}
}

func TestPostStats_OmitsZeroValues(t *testing.T) {
	stats := components.PostStatsData{Distance: 0, TimeSpent: 0, Elevation: 0}
	out := h.Render(t, components.PostStats(stats))
	h.AssertNotContains(t, out, "stat-distance")
	h.AssertNotContains(t, out, "stat-elevation")
	h.AssertNotContains(t, out, "stat-time")
}

func TestPostStats_RendersAllStats(t *testing.T) {
	stats := components.PostStatsData{Distance: 15, TimeSpent: 3, Elevation: 200}
	out := h.Render(t, components.PostStats(stats))
	doc := h.Parse(t, out)

	container := h.FindByClass(doc, "post-stats")
	if len(container) == 0 {
		t.Fatal("expected .post-stats container")
	}

	h.AssertContains(t, out, "15km")
	h.AssertContains(t, out, "200m")
	h.AssertContains(t, out, "3h")
}
