package view

import (
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
)

func llmsTestRouter() *router.Router {
	return router.New("https://example.test")
}

func llmsTestData() *catalog.SiteData {
	return &catalog.SiteData{
		Config: model.SiteConfig{
			Title: "OdkrywajacPolske.pl",
			Desc:  "Spędziłem w terenie {{total_hours}} godzin. {{bicycle_km}}km przejechałem rowerem.",
		},
		Posts: []*model.Post{
			{
				Slug:     "2021-07-18-gotowy",
				Title:    "Gotowy wpis",
				Subtitle: "Podtytuł",
				Date:     time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			},
			{
				Slug:     "2022-01-05-szkic",
				Title:    "Szkic",
				Date:     time.Date(2022, 1, 5, 0, 0, 0, 0, time.UTC),
				TagSlugs: []string{"todo"},
			},
		},
	}
}

// The blockquote must never carry the {{…}} stat placeholders from
// config.yml's site.desc — they are substituted at page-render time and would
// appear literally in a file that is read as-is.
func TestLLMsTxtHasNoStatPlaceholders(t *testing.T) {
	doc := llmsTxtDocument(llmsTestData(), llmsTestRouter())

	if strings.Contains(doc, "{{") || strings.Contains(doc, "}}") {
		t.Errorf("stat placeholders leaked into llms.txt:\n%s", doc)
	}
}

// llms.txt is a published artifact — a draft must never be advertised in it,
// regardless of TARGET.
func TestLLMsTxtExcludesDrafts(t *testing.T) {
	doc := llmsTxtDocument(llmsTestData(), llmsTestRouter())

	if strings.Contains(doc, "Szkic") || strings.Contains(doc, "szkic") {
		t.Errorf("draft post advertised in llms.txt:\n%s", doc)
	}
	if !strings.Contains(doc, "Gotowy wpis") {
		t.Errorf("ready post missing from llms.txt:\n%s", doc)
	}
}

// Every link in llms.txt must be absolute: the file is fetched and read
// standalone, with no page context to resolve relative paths against.
func TestLLMsTxtLinksAreAbsolute(t *testing.T) {
	doc := llmsTxtDocument(llmsTestData(), llmsTestRouter())

	if !strings.Contains(doc, "https://example.test/2021/07/18-gotowy.md") {
		t.Errorf("post link is not the absolute .md alternate:\n%s", doc)
	}
	for _, line := range strings.Split(doc, "\n") {
		if !strings.HasPrefix(line, "- [") {
			continue
		}
		if !strings.Contains(line, "](https://") {
			t.Errorf("non-absolute link in llms.txt: %q", line)
		}
	}
}

func TestLLMsTxtHasRequiredStructure(t *testing.T) {
	doc := llmsTxtDocument(llmsTestData(), llmsTestRouter())

	// llmstxt.org requires an H1 followed by a blockquote summary.
	if !strings.HasPrefix(doc, "# OdkrywajacPolske.pl\n\n> ") {
		t.Errorf("llms.txt must open with H1 then blockquote, got:\n%s", doc)
	}
	for _, section := range []string{"## Wpisy", "## Indeksy", "## Optional"} {
		if !strings.Contains(doc, section) {
			t.Errorf("missing section %q", section)
		}
	}
}
