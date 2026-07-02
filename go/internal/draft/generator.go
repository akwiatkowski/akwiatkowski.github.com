// Package draft generates blog post drafts from GPX ride data.
package draft

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"odkrywajac/internal/draft/gpx"
	"odkrywajac/internal/draft/weather"
)

// Generator produces markdown draft posts.
type Generator struct {
	PostsDir string // Target directory for draft posts (e.g., ../data/posts/2026)
}

// Options configures draft generation.
type Options struct {
	Title        string
	Subtitle     string
	Author       string
	Category     string
	Tags         []string
	ImageFilename string
	Weather      *weather.Data
	DryRun       bool
}

// Generate creates a markdown draft file from GPX statistics.
func (g *Generator) Generate(stats *gpx.RideStats, opts Options) (string, error) {
	date := stats.StartTime.Format("2006-01-02")
	slugName := slugify(opts.Title)
	if slugName == "" {
		slugName = "wycieczka-rowerowa"
	}

	slug := fmt.Sprintf("%s-%s", date, slugName)
	filename := fmt.Sprintf("%s.md", slug)
	outputPath := filepath.Join(g.PostsDir, filename)

	// Ensure posts directory exists
	if !opts.DryRun {
		if err := os.MkdirAll(g.PostsDir, 0755); err != nil {
			return "", fmt.Errorf("create posts directory: %w", err)
		}
	}

	// Build content
	content := g.buildContent(stats, opts, slug)

	if opts.DryRun {
		fmt.Printf("[DRY RUN] Would write to: %s\n", outputPath)
		fmt.Println(content)
		return outputPath, nil
	}

	if err := os.WriteFile(outputPath, []byte(content), 0644); err != nil {
		return "", fmt.Errorf("write draft file: %w", err)
	}

	return outputPath, nil
}

func (g *Generator) buildContent(stats *gpx.RideStats, opts Options, slug string) string {
	var b strings.Builder

	// YAML frontmatter
	b.WriteString("---\n")
	b.WriteString("layout:                 post\n")
	b.WriteString(fmt.Sprintf("title:                  %q\n", opts.Title))
	if opts.Subtitle != "" {
		b.WriteString(fmt.Sprintf("subtitle:               %q\n", opts.Subtitle))
	} else {
		b.WriteString("subtitle:               \"TODO: krótki opis trasy\"\n")
	}
	b.WriteString("desc:                   \"TODO: zdanie podsumowujące wycieczkę\"\n")
	b.WriteString("keywords:               [TODO, słowa, kluczowe]\n")
	b.WriteString(fmt.Sprintf("date:                   %s\n", stats.StartTime.Format("2006-01-02 15:04:05")))
	b.WriteString(fmt.Sprintf("finished_at:            %s\n", time.Now().Format("2006-01-02 15:04:05")))
	b.WriteString(fmt.Sprintf("author:                 %q\n", opts.Author))
	b.WriteString(fmt.Sprintf("categories:             %s\n", opts.Category))

	if opts.ImageFilename != "" {
		b.WriteString(fmt.Sprintf("image_filename:         %s\n", opts.ImageFilename))
	} else {
		b.WriteString("image_filename:         TODO__IMG_0000.jpg\n")
	}
	b.WriteString("image_position:         50% 50%\n")

	tags := opts.Tags
	if len(tags) == 0 {
		tags = []string{"bicycle", "todo"}
	}
	b.WriteString(fmt.Sprintf("tags:                   [%s]\n", strings.Join(tags, ", ")))
	b.WriteString("towns:                  [TODO_wojewodztwo, TODO_gmina]\n")
	b.WriteString("\n")

	// Coords
	b.WriteString(fmt.Sprintf("coords:                 [{\"route\": [], \"type\": %q}]\n", stats.ActivityType))
	b.WriteString(fmt.Sprintf("coords_file:            %q\n", slug+".json"))
	b.WriteString(fmt.Sprintf("coords_type:            %q\n", stats.ActivityType))
	b.WriteString("map_zooms:              12\n")
	b.WriteString(fmt.Sprintf("distance:               %.0f\n", stats.DistanceKm))
	b.WriteString(fmt.Sprintf("time_spent:             %.1f\n", stats.Duration.Hours()))
	b.WriteString(fmt.Sprintf("elevation:              %.0f\n", stats.ElevationGain))

	if opts.Weather != nil {
		b.WriteString(fmt.Sprintf("temperature:            %.0f\n", opts.Weather.Temperature))
	} else {
		b.WriteString("temperature:            20 # TODO\n")
	}

	b.WriteString("\n")
	b.WriteString("pois:\n")
	b.WriteString("#  - lat: 0.00000\n")
	b.WriteString("#    lon: 0.00000\n")
	b.WriteString("#    name: TODO nazwa miejsca\n")
	b.WriteString("#    type: visited\n")
	b.WriteString("\n")
	b.WriteString("strava:\n")
	b.WriteString("#  - https://www.strava.com/activities/TODO\n")
	b.WriteString("\n")
	b.WriteString("---\n")
	b.WriteString("\n")

	// Weather note
	if opts.Weather != nil {
		b.WriteString("<!--\n")
		b.WriteString(fmt.Sprintf("Pogoda podczas wycieczki (okolice %s):\n", stats.StartTime.Format("15:04")))
		b.WriteString(fmt.Sprintf("- Temperatura: %.1f°C\n", opts.Weather.Temperature))
		b.WriteString(fmt.Sprintf("- Zachmurzenie: %d%%\n", opts.Weather.CloudCover))
		b.WriteString(fmt.Sprintf("- Wiatr: %.1f km/h\n", opts.Weather.WindSpeed))
		b.WriteString(fmt.Sprintf("- Opady: %.1f mm\n", opts.Weather.Precipitation))
		b.WriteString("-->\n")
		b.WriteString("\n")
	}

	// Placeholder sections
	b.WriteString("## Wstęp\n")
	b.WriteString("\n")
	b.WriteString("TODO: Krótki wstęp o pogodzie, planie, motywacji.\n")
	b.WriteString("\n")

	b.WriteString("## TODO: Nazwa pierwszej miejscowości\n")
	b.WriteString("\n")
	b.WriteString("TODO: Opis trasy, drogi, wrażenia. Co zauważyłeś?\n")
	b.WriteString("\n")
	b.WriteString("{% photo \"TODO__IMG_0001.jpg\",\"TODO opis zdjęcia\",\"tag:todo\" %}\n")
	b.WriteString("\n")

	b.WriteString("## TODO: Nazwa kolejnej miejscowości lub ciekawego miejsca\n")
	b.WriteString("\n")
	b.WriteString("TODO: Co się wydarzyło? Czy były ciekawe widoki? Trudności?\n")
	b.WriteString("\n")
	b.WriteString("{% photo \"TODO__IMG_0002.jpg\",\"TODO opis zdjęcia\",\"tag:todo\" %}\n")
	b.WriteString("\n")

	b.WriteString("## Powrót\n")
	b.WriteString("\n")
	b.WriteString("TODO: Jak wyglądał powrót? Czy była inna droga?\n")
	b.WriteString("\n")

	b.WriteString("## Dane techniczne\n")
	b.WriteString("\n")
	b.WriteString(fmt.Sprintf("**Długość trasy:** %.1f km\n", stats.DistanceKm))
	b.WriteString(fmt.Sprintf("**Czas w trasie:** %.1f h\n", stats.Duration.Hours()))
	b.WriteString(fmt.Sprintf("**Przewyższenia:** +%.0f m / -%.0f m\n", stats.ElevationGain, stats.ElevationLoss))
	b.WriteString(fmt.Sprintf("**Wysokość min/max:** %.0f m / %.0f m\n", stats.MinElevation, stats.MaxElevation))
	b.WriteString(fmt.Sprintf("**Typ aktywności:** %s\n", stats.ActivityType))
	b.WriteString("\n")

	b.WriteString("---\n")
	b.WriteString("\n")
	b.WriteString("**TODO:** Po zakończeniu wpisu:\n")
	b.WriteString("1. Uzupełnij wszystkie sekcje TODO\n")
	b.WriteString("2. Dodaj zdjęcia i opisy\n")
	b.WriteString("3. Uzupełnij listę miast (towns)\n")
	b.WriteString("4. Usuń tag `todo` z listy tagów\n")
	b.WriteString("5. Zaktualizuj `finished_at`\n")
	b.WriteString("6. Wygeneruj plik JSON z trasą (coords_file)\n")
	b.WriteString("\n")

	return b.String()
}

func slugify(title string) string {
	if title == "" {
		return ""
	}
	s := strings.ToLower(title)
	// Replace Polish characters
	replacements := map[string]string{
		"ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n",
		"ó": "o", "ś": "s", "ź": "z", "ż": "z",
	}
	for old, new := range replacements {
		s = strings.ReplaceAll(s, old, new)
	}
	// Replace spaces and special chars with dashes
	var result strings.Builder
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z':
			result.WriteRune(r)
		case r >= '0' && r <= '9':
			result.WriteRune(r)
		default:
			if result.Len() > 0 && result.String()[result.Len()-1] != '-' {
				result.WriteRune('-')
			}
		}
	}
	return strings.Trim(result.String(), "-")
}
