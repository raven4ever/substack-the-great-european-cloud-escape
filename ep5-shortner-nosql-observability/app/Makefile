# Requires the templ CLI on PATH: go install github.com/a-h/templ/cmd/templ@latest

.PHONY: help generate build run test clean tidy fmt vet

GO ?= go
TEMPL ?= templ
BIN ?= bin/server

help:
	@echo "Targets: generate | build | run | test | clean | tidy | fmt | vet"

# Generate templ Go code from .templ source files
generate:
	$(TEMPL) generate

# Build the server binary (depends on generated templ code)
build: generate
	$(GO) build -o $(BIN) ./cmd/server

# Run locally with sensible defaults
run: generate
	STORAGE_KIND=mongodb \
	MONGODB_URI=mongodb://localhost:27017 \
	TRACE_EXPORTER=none \
	HEARTBEAT_INTERVAL=10s \
	$(GO) run ./cmd/server

# Run tests
test: generate
	$(GO) test ./...

# Format and vet
fmt:
	$(GO) fmt ./...

vet: generate
	$(GO) vet ./...

tidy:
	$(GO) mod tidy

clean:
	rm -rf bin/ templates/*_templ.go
