package obs

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	v4 "github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"go.opentelemetry.io/otel/trace"
	"go.opentelemetry.io/otel/trace/noop"

	"shortner-app/internal/config"
)

const awsXRayService = "xray"

// InitTracing installs the global OTel tracer per cfg.TraceExporter and returns
// a shutdown that flushes pending spans. Shutdown is always safe to call.
// Modes: "none" = noop; "otlp" = OTLP/HTTP (+ optional headers); "xray" =
// OTLP/HTTP with SigV4-signed requests for AWS X-Ray.
func InitTracing(ctx context.Context, cfg *config.Config) (func(context.Context) error, error) {
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	if cfg.TraceExporter == "none" {
		otel.SetTracerProvider(noop.NewTracerProvider())
		return func(context.Context) error { return nil }, nil
	}

	exporter, err := newOTLPExporter(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("create otlp exporter: %w", err)
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(cfg.AppName),
			semconv.ServiceVersion(cfg.Version),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("build resource: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)

	return tp.Shutdown, nil
}

func newOTLPExporter(ctx context.Context, cfg *config.Config) (*otlptrace.Exporter, error) {
	opts := []otlptracehttp.Option{
		otlptracehttp.WithEndpointURL(cfg.OTLPEndpoint),
	}
	if len(cfg.OTLPHeaders) > 0 {
		opts = append(opts, otlptracehttp.WithHeaders(cfg.OTLPHeaders))
	}
	if cfg.OTLPInsecure {
		opts = append(opts, otlptracehttp.WithInsecure())
	}

	if cfg.TraceExporter == "xray" {
		client, err := newSigV4HTTPClient(ctx, cfg.AWSRegion)
		if err != nil {
			return nil, fmt.Errorf("build sigv4 http client: %w", err)
		}
		opts = append(opts, otlptracehttp.WithHTTPClient(client))
	}

	exporter, err := otlptracehttp.New(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("otlptracehttp.New: %w", err)
	}
	return exporter, nil
}

func newSigV4HTTPClient(ctx context.Context, region string) (*http.Client, error) {
	awsCfg, err := awsconfig.LoadDefaultConfig(ctx, awsconfig.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}
	return &http.Client{
		Transport: &sigV4Transport{
			base:    http.DefaultTransport,
			creds:   awsCfg.Credentials,
			signer:  v4.NewSigner(),
			region:  region,
			service: awsXRayService,
		},
	}, nil
}

type sigV4Transport struct {
	base    http.RoundTripper
	creds   aws.CredentialsProvider
	signer  *v4.Signer
	region  string
	service string
}

func (t *sigV4Transport) RoundTrip(req *http.Request) (*http.Response, error) {
	var bodyBytes []byte
	if req.Body != nil {
		var err error
		bodyBytes, err = io.ReadAll(req.Body)
		if err != nil {
			return nil, fmt.Errorf("read request body: %w", err)
		}
		if cerr := req.Body.Close(); cerr != nil {
			return nil, fmt.Errorf("close request body: %w", cerr)
		}
		req.Body = io.NopCloser(bytes.NewReader(bodyBytes))
	}
	sum := sha256.Sum256(bodyBytes)
	payloadHash := hex.EncodeToString(sum[:])

	creds, err := t.creds.Retrieve(req.Context())
	if err != nil {
		return nil, fmt.Errorf("retrieve aws credentials: %w", err)
	}
	if err := t.signer.SignHTTP(req.Context(), creds, req, payloadHash, t.service, t.region, time.Now()); err != nil {
		return nil, fmt.Errorf("sign request: %w", err)
	}
	return t.base.RoundTrip(req)
}

func Tracer(name string) trace.Tracer {
	return otel.Tracer(name)
}
