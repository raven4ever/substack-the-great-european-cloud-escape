FROM golang:1.26-alpine AS builder

WORKDIR /src

# templ CLI version must match go.mod runtime lib.
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    go install github.com/a-h/templ/cmd/templ@v0.3.1020

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

# Regen to match committed .templ source.
RUN templ generate

# UID 65532 = distroless "nonroot". High UID dodges host collisions.
RUN addgroup -g 65532 -S nonroot \
    && adduser  -u 65532 -S -G nonroot -H -D nonroot

# Hardcoded linux/amd64. docker.tf pins platform; no cross-arch flexibility needed.
# CGO_ENABLED=0 + -ldflags -s -w + -trimpath. Static, stripped, reproducible.
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    go build \
        -trimpath \
        -ldflags="-s -w" \
        -o /out/server \
        ./cmd/server

# Runtime: binary + CA bundle + passwd/group. Nothing else.
FROM scratch AS runtime

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group  /etc/group
COPY --from=builder /out/server /server

USER nonroot:nonroot
EXPOSE 8080
ENV PORT=8080
ENTRYPOINT ["/server"]
