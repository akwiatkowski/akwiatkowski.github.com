package render

import (
	"strings"
	"testing"
)

func TestPrettyPrint_BasicIndentation(t *testing.T) {
	input := `<!doctype html><html><head><title>Test</title></head><body><div><p>Hello</p></div></body></html>`
	result, err := PrettyPrint([]byte(input))
	if err != nil {
		t.Fatal(err)
	}

	output := string(result)
	// Should have indented structure
	if !strings.Contains(output, "  <head>") {
		t.Error("head should be indented")
	}
	if !strings.Contains(output, "<title>") {
		t.Error("title should be present")
	}
	if !strings.Contains(output, "  <body>") {
		t.Error("body should be indented")
	}
}

func TestPrettyPrint_PreserveScript(t *testing.T) {
	input := `<!doctype html><html><head><title>T</title></head><body><script>var x = 1;
if (x > 0) { alert("hi"); }</script></body></html>`
	result, err := PrettyPrint([]byte(input))
	if err != nil {
		t.Fatal(err)
	}

	output := string(result)
	// Script content should be preserved
	if !strings.Contains(output, `var x = 1;`) {
		t.Error("script content should be preserved")
	}
}

func TestPrettyPrint_PreservePre(t *testing.T) {
	input := `<!doctype html><html><head><title>T</title></head><body><pre>  indented
    more indented</pre></body></html>`
	result, err := PrettyPrint([]byte(input))
	if err != nil {
		t.Fatal(err)
	}

	output := string(result)
	if !strings.Contains(output, "  indented\n    more indented") {
		t.Errorf("pre content should be preserved, got:\n%s", output)
	}
}

func TestPrettyPrint_SelfClosingTags(t *testing.T) {
	input := `<!doctype html><html><head><title>T</title><meta charset="utf-8"><link rel="stylesheet" href="a.css"></head><body><img src="x.jpg"><br></body></html>`
	result, err := PrettyPrint([]byte(input))
	if err != nil {
		t.Fatal(err)
	}

	output := string(result)
	if !strings.Contains(output, `<meta charset="utf-8"/>`) {
		t.Errorf("meta should be self-closing, got:\n%s", output)
	}
	if !strings.Contains(output, `<img src="x.jpg"/>`) {
		t.Errorf("img should be self-closing, got:\n%s", output)
	}
}
