package pipeline

import (
	"testing"
)

func TestContextPathHelpers(t *testing.T) {
	ctx := &Context{
		Env:      "dev",
		Target:   "go",
		BasePath: "/project",
	}

	tests := []struct {
		name string
		got  string
		want string
	}{
		{"PostsDir", ctx.PostsDir(), "/project/env/dev/data/posts"},
		{"ImagesDir", ctx.ImagesDir(), "/project/env/dev/data/images"},
		{"RoutesDir", ctx.RoutesDir(), "/project/env/dev/data/routes"},
		{"CacheDir", ctx.CacheDir(), "/project/env/dev/cache-go"},
		{"OutputDir", ctx.OutputDir(), "/project/env/dev/public/go"},
		{"ConfigDir", ctx.ConfigDir(), "/project/data/config"},
		{"ExternalDir", ctx.ExternalDir(), "/project/data/external"},
		{"GeneratedCacheDir", ctx.GeneratedCacheDir(), "/project/go-rewrite/cache"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.got != tt.want {
				t.Errorf("got %q, want %q", tt.got, tt.want)
			}
		})
	}
}

func TestContextPathHelpersFullEnv(t *testing.T) {
	ctx := &Context{
		Env:      "full",
		Target:   "go",
		BasePath: "/project",
	}

	if got := ctx.PostsDir(); got != "/project/env/full/data/posts" {
		t.Errorf("PostsDir() = %q, want /project/env/full/data/posts", got)
	}
	if got := ctx.OutputDir(); got != "/project/env/full/public/go" {
		t.Errorf("OutputDir() = %q, want /project/env/full/public/go", got)
	}
}

func TestContextResults(t *testing.T) {
	ctx := &Context{}

	// No result initially
	if _, ok := ctx.Result("foo"); ok {
		t.Error("expected no result for 'foo'")
	}

	// Store and retrieve
	ctx.StoreResult("foo", 42)
	val, ok := ctx.Result("foo")
	if !ok {
		t.Fatal("expected result for 'foo'")
	}
	if val.(int) != 42 {
		t.Errorf("got %v, want 42", val)
	}

	// Overwrite
	ctx.StoreResult("foo", "bar")
	val, _ = ctx.Result("foo")
	if val.(string) != "bar" {
		t.Errorf("got %v, want 'bar'", val)
	}
}
