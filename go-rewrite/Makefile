.PHONY: templ-generate build test vet lint render render-full render-verbose install-deps

# CGO flags for GEOS C library (required by spatial matching)
export CGO_CFLAGS := $(shell geos-config --cflags 2>/dev/null)
export CGO_LDFLAGS := $(shell geos-config --libs 2>/dev/null)

templ-generate:
	mise exec -- templ generate

build: templ-generate
	mise exec -- go build -o bin/odkrywajac ./cmd/odkrywajac

test:
	mise exec -- go test ./...

vet:
	mise exec -- go vet ./...

lint:
	mise exec -- golangci-lint run ./...

# Render the blog (dev environment by default)
render: build
	./bin/odkrywajac build --base .. --env dev

render-full: build
	./bin/odkrywajac build --base .. --env full

render-verbose: build
	./bin/odkrywajac build --base .. --env dev --verbose

# Install system dependencies
install-deps:
	brew install geos
