package model

import (
	"testing"
	"time"
)

func TestBuildPostURL(t *testing.T) {
	tests := []struct {
		date time.Time
		slug string
		want string
	}{
		{
			date: time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			slug: "pagorki-przed-zniwami",
			want: "/2021/07/18-pagorki-przed-zniwami.html",
		},
		{
			date: time.Date(2018, 11, 5, 0, 0, 0, 0, time.UTC),
			slug: "spacer-na-przedmiescia",
			want: "/2018/11/05-spacer-na-przedmiescia.html",
		},
	}
	for _, tt := range tests {
		got := BuildPostURL(tt.date, tt.slug)
		if got != tt.want {
			t.Errorf("BuildPostURL(%v, %q) = %q, want %q", tt.date, tt.slug, got, tt.want)
		}
	}
}

func TestPostIsFinished(t *testing.T) {
	// Unfinished post
	p := &Post{}
	if p.IsFinished() {
		t.Error("post with nil FinishedAt should not be finished")
	}

	// Post finished in the past
	past := time.Now().Add(-24 * time.Hour)
	p.FinishedAt = &past
	if !p.IsFinished() {
		t.Error("post with past FinishedAt should be finished")
	}

	// Post "finished" in the far future (draft marker)
	future := time.Date(2100, 1, 1, 0, 0, 0, 0, time.UTC)
	p.FinishedAt = &future
	if p.IsFinished() {
		t.Error("post with future FinishedAt should not be finished")
	}
}

func TestPostYear(t *testing.T) {
	p := &Post{Date: time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC)}
	if p.Year() != 2021 {
		t.Errorf("Year() = %d, want 2021", p.Year())
	}
}
