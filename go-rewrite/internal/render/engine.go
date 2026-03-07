// Package render provides the parallel rendering engine and file writer.
package render

import (
	"bytes"
	"fmt"
	"strings"
	"sync"
	"time"

	"odkrywajac/internal/view"
)

// Result holds the outcome of a render operation.
type Result struct {
	TotalViews int
	Written    int64
	Skipped    int64
	Errors     []error
	Duration   time.Duration
	ValErrors  []ValidationError
}

// Render renders all views in parallel and writes output to disk.
func Render(views []view.Renderable, outputDir string, manifest *Manifest, workers int) Result {
	start := time.Now()
	result := Result{TotalViews: len(views)}

	if workers <= 0 {
		workers = 1
	}

	writer := NewWriter(outputDir, manifest)

	// Channel for rendered output files
	outputCh := make(chan OutputFile, workers*2)

	// Writer goroutines
	var writerWg sync.WaitGroup
	var writeErrors []error
	var writeMu sync.Mutex
	writerCount := min(4, workers)
	writerWg.Add(writerCount)
	for i := 0; i < writerCount; i++ {
		go func() {
			defer writerWg.Done()
			for file := range outputCh {
				if err := writer.Write(file); err != nil {
					writeMu.Lock()
					writeErrors = append(writeErrors, err)
					writeMu.Unlock()
				}
			}
		}()
	}

	// Render goroutines with bounded semaphore
	sem := make(chan struct{}, workers)
	var renderWg sync.WaitGroup
	var renderErrors []error
	var renderMu sync.Mutex
	var valErrors []ValidationError
	var valMu sync.Mutex

	for _, v := range views {
		renderWg.Add(1)
		sem <- struct{}{} // acquire semaphore
		go func(v view.Renderable) {
			defer renderWg.Done()
			defer func() { <-sem }() // release semaphore

			var buf bytes.Buffer
			if err := v.Render(&buf); err != nil {
				renderMu.Lock()
				renderErrors = append(renderErrors, fmt.Errorf("render %s: %w", v.URL(), err))
				renderMu.Unlock()
				return
			}

			content := buf.Bytes()

			// Pretty-print HTML pages
			if strings.HasSuffix(v.URL(), ".html") {
				if pretty, err := PrettyPrint(content); err == nil {
					content = pretty
				}
			}

			// Validate HTML
			if errs := ValidateHTML(v.URL(), content); len(errs) > 0 {
				valMu.Lock()
				valErrors = append(valErrors, errs...)
				valMu.Unlock()
			}

			outputCh <- OutputFile{URL: v.URL(), Content: content}
		}(v)
	}

	// Wait for all renders, then close channel so writers finish
	renderWg.Wait()
	close(outputCh)
	writerWg.Wait()

	result.Written, result.Skipped = writer.Stats()
	result.Errors = append(renderErrors, writeErrors...)
	result.ValErrors = valErrors
	result.Duration = time.Since(start)

	return result
}
