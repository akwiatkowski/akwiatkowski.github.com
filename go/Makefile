.PHONY: templ-generate build test vet lint render render-full render-verbose render-full-verbose gpx-draft missing-posts install-deps

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

render-full-verbose: build
	./bin/odkrywajac build --base .. --env full --verbose

# Generate a draft blog post from a GPX file or Strava activity ID
# Usage: make gpx-draft GPX=path/to/ride.gpx TITLE="My Ride"
# Usage: make gpx-draft ID=12345678 [TITLE="My Ride"]
gpx-draft: build
	@if [ -z "$(GPX)" ] && [ -z "$(ID)" ]; then echo "Error: GPX=path/to/file.gpx or ID=12345 is required"; exit 1; fi
	@if [ -n "$(ID)" ]; then \
		./bin/odkrywajac gpx-draft -id "$(ID)" $(if $(TITLE),-title "$(TITLE)"); \
	else \
		./bin/odkrywajac gpx-draft -gpx "$(GPX)" -title "$(TITLE)"; \
	fi

# List Strava activities missing blog posts
missing-posts: build
	./bin/odkrywajac missing-posts

# Install system dependencies
install-deps:
	brew install geos
