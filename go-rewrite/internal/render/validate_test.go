package render

import (
	"testing"
)

func TestValidateHTML_ValidPage(t *testing.T) {
	html := []byte(`<!doctype html><html><head><title>Test Page</title></head><body><p>Hello</p></body></html>`)
	errs := ValidateHTML("/test.html", html)
	if len(errs) != 0 {
		t.Errorf("expected no errors, got %v", errs)
	}
}

func TestValidateHTML_MissingTitle(t *testing.T) {
	html := []byte(`<!doctype html><html><head></head><body></body></html>`)
	errs := ValidateHTML("/test.html", html)
	found := false
	for _, e := range errs {
		if e.Message == "missing or empty <title>" {
			found = true
		}
	}
	if !found {
		t.Error("expected missing title error")
	}
}

func TestValidateHTML_EmptyHref(t *testing.T) {
	html := []byte(`<!doctype html><html><head><title>T</title></head><body><a href="">link</a></body></html>`)
	errs := ValidateHTML("/test.html", html)
	found := false
	for _, e := range errs {
		if e.Message == `empty href on <a>` {
			found = true
		}
	}
	if !found {
		t.Errorf("expected empty href error, got %v", errs)
	}
}

func TestValidateHTML_DuplicateID(t *testing.T) {
	html := []byte(`<!doctype html><html><head><title>T</title></head><body><div id="x"></div><div id="x"></div></body></html>`)
	errs := ValidateHTML("/test.html", html)
	found := false
	for _, e := range errs {
		if e.Message == `duplicate id="x"` {
			found = true
		}
	}
	if !found {
		t.Errorf("expected duplicate id error, got %v", errs)
	}
}

func TestValidateHTML_NonHTML(t *testing.T) {
	errs := ValidateHTML("/data.json", []byte(`{"ok":true}`))
	if len(errs) != 0 {
		t.Error("JSON should not be validated as HTML")
	}
}
