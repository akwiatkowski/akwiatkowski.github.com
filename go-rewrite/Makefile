.PHONY: templ-generate build test vet

templ-generate:
	templ generate

build: templ-generate
	go build -o bin/odkrywajac ./cmd/odkrywajac

test:
	go test ./...

vet:
	go vet ./...
