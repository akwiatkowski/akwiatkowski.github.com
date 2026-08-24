package view

import (
	"fmt"
	"io"
	"sort"
	"strings"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
)

// llmsRecentPostCount caps how many recent posts llms.txt lists by name.
//
// llms.txt is a curated entry point, not a sitemap — the whole point is to
// give a model a readable map of the site rather than every URL on it. The
// full corpus is already reachable via sitemap.xml and the index pages linked
// below, so this lists enough recent work to convey what the site is without
// turning into a 500-line dump.
const llmsRecentPostCount = 40

// LLMsTxt creates a Renderable for /llms.txt, the llmstxt.org site index for
// LLMs and AI agents.
//
// Every entry points at a Markdown representation where one exists (posts) and
// at the HTML page otherwise (index pages, which are interactive and have no
// meaningful Markdown form).
func LLMsTxt(data *catalog.SiteData, r *router.Router) Renderable {
	return NewRawEndpoint(r.LLMsTxtURL(), false, func(w io.Writer) error {
		_, err := io.WriteString(w, llmsTxtDocument(data, r))
		return err
	})
}

// llmsTxtDocument builds the llms.txt body.
func llmsTxtDocument(data *catalog.SiteData, r *router.Router) string {
	var b strings.Builder

	fmt.Fprintf(&b, "# %s\n\n", data.Config.Title)
	fmt.Fprintf(&b, "> %s\n\n", llmsSummary)

	b.WriteString("Autor jeździ rowerem i chodzi pieszo po Polsce, fotografując miejsca, ")
	b.WriteString("o których zwykle się nie mówi — małe miejscowości, dawne linie kolejowe, ")
	b.WriteString("krajobraz rolniczy. Każdy wpis opisuje jedną wycieczkę: przebytą trasę, ")
	b.WriteString("mijane miejscowości (z odnośnikami do Wikipedii) i zdjęcia z drogi. ")
	b.WriteString("Treść jest w języku polskim.\n\n")

	b.WriteString("Każdy wpis jest dostępny także w czystym Markdownie — ten sam adres z rozszerzeniem `.md` zamiast `.html`.\n\n")

	b.WriteString("## Strona główna\n\n")
	llmsEntry(&b, "Strona główna", r.CanonicalURL(r.HomeURL()), "Najnowsze wycieczki i statystyki")
	llmsEntry(&b, "O mnie", r.CanonicalURL(r.AboutURL()), "Autor i cel strony")
	llmsEntry(&b, "English summary", r.CanonicalURL(r.EnglishURL()), "Short description in English")

	b.WriteString("\n## Wpisy\n\n")
	for _, post := range llmsRecentPosts(data) {
		llmsEntry(&b, post.Title, r.CanonicalURL(r.PostMarkdownURL(post)), llmsPostNote(post))
	}

	b.WriteString("\n## Indeksy\n\n")
	llmsEntry(&b, "Gminy", r.CanonicalURL(r.TownsIndexURL()), "Wszystkie odwiedzone gminy")
	llmsEntry(&b, "Województwa", r.CanonicalURL(r.VoivodeshipsIndexURL()), "Wpisy pogrupowane według województw")
	llmsEntry(&b, "Krainy", r.CanonicalURL(r.LandsIndexURL()), "Krainy geograficzne")
	llmsEntry(&b, "Regiony", r.CanonicalURL(r.MesoRegionsIndexURL()), "Mezoregiony fizycznogeograficzne")
	llmsEntry(&b, "Tagi", r.CanonicalURL(r.TagsIndexURL()), "Wpisy pogrupowane tematycznie")
	llmsEntry(&b, "Galeria", r.CanonicalURL(r.GalleryIndexURL()), "Zdjęcia ze wszystkich wycieczek")

	b.WriteString("\n## Optional\n\n")
	llmsEntry(&b, "Mapa tras", r.CanonicalURL(r.MapURL()), "Interaktywna mapa wszystkich tras")
	llmsEntry(&b, "Mapa zdjęć", r.CanonicalURL(r.PhotoMapURL()), "Zdjęcia naniesione na mapę")
	llmsEntry(&b, "Linia czasu", r.CanonicalURL(r.TimelineURL()), "Wycieczki chronologicznie")
	llmsEntry(&b, "RSS", r.CanonicalURL(r.RSSURL()), "Kanał RSS")
	llmsEntry(&b, "Sitemap", r.CanonicalURL(r.SitemapURL()), "Pełna lista adresów")

	return b.String()
}

// llmsEntry writes one `- [Name](url): note` list item.
func llmsEntry(b *strings.Builder, name, url, note string) {
	if note == "" {
		fmt.Fprintf(b, "- [%s](%s)\n", name, url)
		return
	}
	fmt.Fprintf(b, "- [%s](%s): %s\n", name, url, note)
}

// llmsRecentPosts returns the most recent ready posts, newest first, capped at
// llmsRecentPostCount. Not-ready (todo/draft) posts are excluded regardless of
// TARGET — llms.txt is a published artifact and must never advertise drafts.
func llmsRecentPosts(data *catalog.SiteData) []*model.Post {
	ready := make([]*model.Post, 0, len(data.Posts))
	for _, post := range data.Posts {
		if post.IsReady() {
			ready = append(ready, post)
		}
	}
	sort.Slice(ready, func(i, j int) bool {
		return ready[i].Date.After(ready[j].Date)
	})
	if len(ready) > llmsRecentPostCount {
		ready = ready[:llmsRecentPostCount]
	}
	return ready
}

// llmsPostNote builds the short note after a post link: its date, plus the
// subtitle when the post has one.
func llmsPostNote(post *model.Post) string {
	note := post.Date.Format("2006-01-02")
	if post.Subtitle != "" {
		note += " — " + post.Subtitle
	}
	return note
}

// llmsSummary is the one-sentence blockquote that llmstxt.org requires
// directly under the H1.
//
// It is written for this file rather than derived from `site.desc` in
// config.yml: that description is built around `{{total_hours}}`-style
// placeholders which are substituted during page rendering, and stripping them
// here leaves a mangled sentence ("Spędziłem w terenie godzin."). A model
// reads this line first, so it is worth stating plainly.
const llmsSummary = "Blog rowerowo-fotograficzny o odkrywaniu mniej znanych miejsc w Polsce — " +
	"relacje z wycieczek rowerowych i pieszych, z trasami, zdjęciami i opisami mijanych miejscowości."
