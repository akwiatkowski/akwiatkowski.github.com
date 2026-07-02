package e2e

import (
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/go-rod/rod"
	"github.com/go-rod/rod/lib/launcher"
)

// testServer holds the HTTP server and browser for E2E tests.
type testServer struct {
	URL     string
	server  *http.Server
	browser *rod.Browser
}

// projectRoot returns the absolute path to the project root (go-rewrite/..).
func projectRoot() string {
	_, file, _, _ := runtime.Caller(0)
	// file is go-rewrite/e2e/helpers_test.go → go up 2 levels
	return filepath.Dir(filepath.Dir(filepath.Dir(file)))
}

// outputDir returns the Go output directory for the given env. Output is
// engine-agnostic now (env/<env>/public/<target>); the e2e suite checks the
// local target where Go writes by default.
func outputDir(env string) string {
	return filepath.Join(projectRoot(), "env", env, "public", "local")
}

// setupServer starts an HTTP file server on a random port serving the Go output.
// Skips the test if the output directory doesn't exist.
func setupServer(t *testing.T) *testServer {
	t.Helper()

	// Try dev first, then full
	dir := outputDir("dev")
	if _, err := os.Stat(dir); err != nil {
		dir = outputDir("full")
		if _, err := os.Stat(dir); err != nil {
			t.Skipf("No Go output directory found (tried dev and full). Build the site first.")
		}
	}

	// Verify index.html exists
	if _, err := os.Stat(filepath.Join(dir, "index.html")); err != nil {
		t.Skipf("No index.html in %s. Build the site first.", dir)
	}

	// Find a free port
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("failed to find free port: %v", err)
	}
	port := listener.Addr().(*net.TCPAddr).Port
	listener.Close()

	// Start file server
	mux := http.NewServeMux()
	mux.Handle("/", http.FileServer(http.Dir(dir)))
	server := &http.Server{
		Addr:    fmt.Sprintf("127.0.0.1:%d", port),
		Handler: mux,
	}

	go server.ListenAndServe()

	ts := &testServer{
		URL:    fmt.Sprintf("http://127.0.0.1:%d", port),
		server: server,
	}

	// Wait for server to be ready
	for i := 0; i < 50; i++ {
		conn, err := net.DialTimeout("tcp", server.Addr, 100*time.Millisecond)
		if err == nil {
			conn.Close()
			break
		}
		time.Sleep(20 * time.Millisecond)
	}

	t.Cleanup(func() {
		ts.teardown()
	})

	return ts
}

// setupBrowser launches a headless Rod browser.
func (ts *testServer) setupBrowser(t *testing.T) *rod.Browser {
	t.Helper()

	if ts.browser != nil {
		return ts.browser
	}

	path, _ := launcher.LookPath()
	if path == "" {
		t.Skip("No Chrome/Chromium found. Install a browser for E2E tests.")
	}

	u := launcher.New().Bin(path).Headless(true).MustLaunch()
	browser := rod.New().ControlURL(u).MustConnect()

	ts.browser = browser

	return browser
}

// teardown stops the server and closes the browser.
func (ts *testServer) teardown() {
	if ts.browser != nil {
		ts.browser.MustClose()
	}
	if ts.server != nil {
		ts.server.Close()
	}
}

// newPage creates a new browser page navigated to the given path.
// Waits for the page to load and JS to execute.
func (ts *testServer) newPage(t *testing.T, path string) *rod.Page {
	t.Helper()
	browser := ts.setupBrowser(t)
	page := browser.MustPage("")
	page.MustNavigate(ts.URL + path)
	// Wait for page load + JS execution
	time.Sleep(3 * time.Second)
	return page
}

// jsEval evaluates a JS arrow function and returns the string result.
// Returns ("", error) if evaluation fails.
func jsEval(page *rod.Page, expr string) (string, error) {
	res, err := page.Eval(expr)
	if err != nil {
		return "", err
	}
	if res == nil || res.Value.Nil() {
		return "", nil
	}
	return res.Value.String(), nil
}

// jsEvalInt evaluates a JS arrow function and returns the int result.
func jsEvalInt(page *rod.Page, expr string) (int, error) {
	res, err := page.Eval(expr)
	if err != nil {
		return 0, err
	}
	if res == nil || res.Value.Nil() {
		return 0, nil
	}
	return res.Value.Int(), nil
}

// jsEvalBool evaluates a JS arrow function and returns the bool result.
func jsEvalBool(page *rod.Page, expr string) (bool, error) {
	res, err := page.Eval(expr)
	if err != nil {
		return false, err
	}
	if res == nil || res.Value.Nil() {
		return false, nil
	}
	return res.Value.Bool(), nil
}

// waitForJS waits until a JS arrow function returns true.
func waitForJS(page *rod.Page, expr string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		ok, err := jsEvalBool(page, expr)
		if err == nil && ok {
			return nil
		}
		time.Sleep(200 * time.Millisecond)
	}
	return fmt.Errorf("timeout waiting for: %s", expr)
}
