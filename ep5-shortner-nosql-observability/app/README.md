# shortner

URL shortener used as the worked example for **Episode 5** of *The Great
European Cloud Escape* — a head-to-head between AWS ECS Express and
Scaleway Serverless Containers. Same Go binary, two clouds, two NoSQL
backends, identical observability surface.

## Stack

- **Go 1.26**, Echo v4, [templ](https://templ.guide) for type-safe HTML.
- **htmx** for partial-update form submissions, **Material Web Components**
  (loaded from `esm.run`) for the form controls.
- **Storage**: pluggable behind a `Store` interface — DynamoDB on AWS,
  MongoDB on Scaleway. Records are full UUIDv7 IDs; the user-facing slug
  is an 8-char base62 derivation of the random portion.
- **TTL** is enforced at the storage layer (DynamoDB TTL attribute /
  Mongo TTL index). Default is 24 h, configurable via `DEFAULT_TTL`, and
  the user can override per link from the homepage form.
- **Observability**: structured `slog` JSON logs, Prometheus metrics
  at `/metrics`, OpenTelemetry traces (OTLP or AWS X-Ray via SigV4).

## Quickstart

```bash
# 1. install the templ CLI once
go install github.com/a-h/templ/cmd/templ@latest

# 2. generate templ Go code, build, run
make generate
make build
make run
```

The default `make run` target points at a local MongoDB at
`mongodb://localhost:27017` and disables tracing. Override env vars to
point at DynamoDB / a real OTLP collector.

## Required tools

- Go **1.26**
- `templ` CLI (above)
- A local MongoDB (e.g. `docker run -p 27017:27017 mongo:7`) **or** AWS
  credentials with access to a DynamoDB table whose name matches
  `DYNAMODB_TABLE`.

## Environment variables

| Variable | Default | Notes |
|---|---|---|
| `APP_NAME` | `shortner` | Service name reported in traces / logs. |
| `APP_VERSION` | `dev` | Build version. |
| `PORT` | `8080` | HTTP listen port. |
| `LOG_LEVEL` | `info` | `debug`, `info`, `warn`, `error`. |
| `STORAGE_KIND` | `mongodb` | `mongodb` or `dynamodb`. |
| `DYNAMODB_TABLE` | `shortner-links` | DynamoDB table name. |
| `DYNAMODB_REGION` | *(empty)* | Falls back to `AWS_REGION`. |
| `MONGODB_URI` | `mongodb://localhost:27017` | Mongo connection string. |
| `MONGODB_DATABASE` | `shortner` | Database name. |
| `MONGODB_COLLECTION` | `links` | Collection name. |
| `DEFAULT_TTL` | `24h` | Default expiry for new links. |
| `TRACE_EXPORTER` | `none` | `none`, `otlp`, or `xray`. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | *(empty)* | Required if not `none`. |
| `OTEL_EXPORTER_OTLP_HEADERS` | *(empty)* | `k1=v1,k2=v2` form. |
| `OTEL_EXPORTER_OTLP_INSECURE` | `false` | Disable TLS to the collector. |
| `AWS_REGION` | *(empty)* | Required if `TRACE_EXPORTER=xray`. |
| `HEARTBEAT_INTERVAL` | `10s` | How often to emit synthetic noise. |
| `HEARTBEAT_PAYLOAD_KB` | `5` | Size of the synthetic payload. |
| `CHAOS_RATE` | `0.01` | Fraction of requests the chaos middleware fails. |
| `SHUTDOWN_TIMEOUT` | `10s` | Graceful shutdown deadline. |

## What's interesting about this code

- **Storage symmetry** — `storage.Store` is implemented twice with
  identical semantics (TTL, click counter atomicity, list ordering)
  against very different engines. The implementation files are short
  enough to diff side-by-side.
- **SigV4 X-Ray transport** — the OTLP HTTP exporter is wrapped with a
  custom `http.RoundTripper` that signs requests with AWS SigV4, which
  is what X-Ray's OTLP endpoint actually requires. Worth reading if
  you've ever wondered why "just point OTLP at X-Ray" is harder than
  the docs make it look.
- **Heartbeat noise** — a goroutine that periodically logs, traces,
  and emits a synthetic payload, useful for filling dashboards during
  the demo and for cost-comparison numbers between AWS CloudWatch and
  Scaleway Cockpit.
- **Chaos middleware** — a configurable `CHAOS_RATE` that randomly
  500s some fraction of requests, so the metrics middleware actually
  has error counters to chart.
