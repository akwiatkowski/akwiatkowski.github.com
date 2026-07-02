package content

import (
	"testing"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/parser"
	"github.com/yuin/goldmark/text"
)

func parse(src string) ExtractedData {
	md := goldmark.New(goldmark.WithExtensions(&Extension{}))
	reader := text.NewReader([]byte(src))
	doc := md.Parser().Parse(reader, parser.WithContext(parser.NewContext()))
	return Extract(doc)
}

func TestParsePhoto(t *testing.T) {
	src := `Some text

{% photo "2021_07_18__11_18__7189980.jpg","Rząd domów w Laskowicach" %}

More text
`
	data := parse(src)
	if len(data.Photos) != 1 {
		t.Fatalf("expected 1 photo, got %d", len(data.Photos))
	}
	p := data.Photos[0]
	if p.Filename != "2021_07_18__11_18__7189980.jpg" {
		t.Errorf("filename = %q", p.Filename)
	}
	if p.Caption != "Rząd domów w Laskowicach" {
		t.Errorf("caption = %q", p.Caption)
	}
	if len(p.Tags) != 0 {
		t.Errorf("tags = %v, want empty", p.Tags)
	}
}

func TestParsePhotoWithTags(t *testing.T) {
	src := `{% photo "img.jpg","Motyl","tag:macro,tag:good" %}
`
	data := parse(src)
	if len(data.Photos) != 1 {
		t.Fatalf("expected 1 photo, got %d", len(data.Photos))
	}
	p := data.Photos[0]
	if p.Filename != "img.jpg" {
		t.Errorf("filename = %q", p.Filename)
	}
	if p.Caption != "Motyl" {
		t.Errorf("caption = %q", p.Caption)
	}
	if len(p.Tags) != 2 || p.Tags[0] != "macro" || p.Tags[1] != "good" {
		t.Errorf("tags = %v, want [macro, good]", p.Tags)
	}
}

func TestParsePhotoHeader(t *testing.T) {
	src := `{% photo_header "Droga ze wsi","tag:summer,tag:timeline,tag:rural" %}

Some text
`
	data := parse(src)
	if data.HeaderPhoto == nil {
		t.Fatal("expected header photo")
	}
	h := data.HeaderPhoto
	if h.Caption != "Droga ze wsi" {
		t.Errorf("caption = %q", h.Caption)
	}
	if len(h.Tags) != 3 {
		t.Errorf("tags = %v, want 3 tags", h.Tags)
	}
	if !h.IsHeader {
		t.Error("expected IsHeader to be true")
	}
}

func TestParsePostURL(t *testing.T) {
	src := `From [earlier]({% post_url 2021-06-03-pociagiem-z-kutna %}) trip.
`
	data := parse(src)
	if len(data.CrossRefs) != 1 {
		t.Fatalf("expected 1 crossref, got %d", len(data.CrossRefs))
	}
	if data.CrossRefs[0] != "2021-06-03-pociagiem-z-kutna" {
		t.Errorf("crossref = %q", data.CrossRefs[0])
	}
}

func TestParseMultipleDirectives(t *testing.T) {
	src := `{% photo_header "Header caption","tag:best" %}

## Section

{% photo "a.jpg","Photo A" %}

Some text with [link]({% post_url 2021-01-01-slug %}).

{% photo "b.jpg","Photo B","tag:good" %}
`
	data := parse(src)

	if data.HeaderPhoto == nil {
		t.Error("expected header photo")
	}
	if len(data.Photos) != 2 {
		t.Errorf("expected 2 photos, got %d", len(data.Photos))
	}
	if len(data.CrossRefs) != 1 {
		t.Errorf("expected 1 crossref, got %d", len(data.CrossRefs))
	}
}

func TestSplitQuotedArgs(t *testing.T) {
	tests := []struct {
		input string
		want  []string
	}{
		{`"a","b","c"`, []string{"a", "b", "c"}},
		{`"hello"`, []string{"hello"}},
		{`"one","two"`, []string{"one", "two"}},
		{`"has spaces","tag:a,tag:b"`, []string{"has spaces", "tag:a,tag:b"}},
	}
	for _, tt := range tests {
		got := splitQuotedArgs(tt.input)
		if len(got) != len(tt.want) {
			t.Errorf("splitQuotedArgs(%q) = %v, want %v", tt.input, got, tt.want)
			continue
		}
		for i := range got {
			if got[i] != tt.want[i] {
				t.Errorf("splitQuotedArgs(%q)[%d] = %q, want %q", tt.input, i, got[i], tt.want[i])
			}
		}
	}
}

func TestParseTags(t *testing.T) {
	tags := parseTags("tag:summer,tag:timeline,tag:rural")
	if len(tags) != 3 {
		t.Fatalf("expected 3 tags, got %d: %v", len(tags), tags)
	}
	expected := []string{"summer", "timeline", "rural"}
	for i, want := range expected {
		if tags[i] != want {
			t.Errorf("tags[%d] = %q, want %q", i, tags[i], want)
		}
	}
}

func TestParseGeo(t *testing.T) {
	src := `Some text {% geo 52.45,16.93 %} more text.
`
	md := goldmark.New(goldmark.WithExtensions(&Extension{}))
	reader := text.NewReader([]byte(src))
	doc := md.Parser().Parse(reader, parser.WithContext(parser.NewContext()))

	found := false
	ast.Walk(doc, func(n ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			return ast.WalkContinue, nil
		}
		if geo, ok := n.(*GeoNode); ok {
			found = true
			if geo.Lat != 52.45 {
				t.Errorf("lat = %f, want 52.45", geo.Lat)
			}
			if geo.Lon != 16.93 {
				t.Errorf("lon = %f, want 16.93", geo.Lon)
			}
		}
		return ast.WalkContinue, nil
	})
	if !found {
		t.Error("expected GeoNode")
	}
}

func TestParseProTip(t *testing.T) {
	src := `{% pro_tip %} Pack extra water.
`
	md := goldmark.New(goldmark.WithExtensions(&Extension{}))
	reader := text.NewReader([]byte(src))
	doc := md.Parser().Parse(reader, parser.WithContext(parser.NewContext()))

	found := false
	ast.Walk(doc, func(n ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			return ast.WalkContinue, nil
		}
		if _, ok := n.(*ProTipNode); ok {
			found = true
		}
		return ast.WalkContinue, nil
	})
	if !found {
		t.Error("expected ProTipNode")
	}
}

func TestParseCurrentYear(t *testing.T) {
	src := `Copyright {% current_year %}.
`
	md := goldmark.New(goldmark.WithExtensions(&Extension{}))
	reader := text.NewReader([]byte(src))
	doc := md.Parser().Parse(reader, parser.WithContext(parser.NewContext()))

	found := false
	ast.Walk(doc, func(n ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			return ast.WalkContinue, nil
		}
		if _, ok := n.(*CurrentYearNode); ok {
			found = true
		}
		return ast.WalkContinue, nil
	})
	if !found {
		t.Error("expected CurrentYearNode")
	}
}

func TestParseTodo(t *testing.T) {
	src := `Some text {% todo %} more text.
`
	md := goldmark.New(goldmark.WithExtensions(&Extension{}))
	reader := text.NewReader([]byte(src))
	doc := md.Parser().Parse(reader, parser.WithContext(parser.NewContext()))

	found := false
	ast.Walk(doc, func(n ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			return ast.WalkContinue, nil
		}
		if _, ok := n.(*TodoNode); ok {
			found = true
		}
		return ast.WalkContinue, nil
	})
	if !found {
		t.Error("expected TodoNode")
	}
}

func TestParseGeoArgs(t *testing.T) {
	lat, lon, ok := parseGeoArgs("52.45,16.93")
	if !ok {
		t.Fatal("expected ok=true")
	}
	if lat != 52.45 {
		t.Errorf("lat = %f, want 52.45", lat)
	}
	if lon != 16.93 {
		t.Errorf("lon = %f, want 16.93", lon)
	}

	_, _, ok = parseGeoArgs("invalid")
	if ok {
		t.Error("expected ok=false for invalid input")
	}
}
