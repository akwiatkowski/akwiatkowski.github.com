.PHONY: templ-generate build test vet lint render render-full render-verbose

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
