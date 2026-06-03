package web

import (
	"context"
	"log/slog"
	"strconv"

	"github.com/google/uuid"
	"github.com/labstack/echo/v5"
	"github.com/labstack/echo/v5/middleware"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/propagation"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"go.opentelemetry.io/otel/trace"

	"shortner-app/internal/obs"
)

const requestIDHeader = "X-Request-ID"

const requestIDKey = "request_id"

const otelTracerName = "shortner-app/web"

func RequestID() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c *echo.Context) error {
			rid := c.Request().Header.Get(requestIDHeader)
			if rid == "" {
				rid = uuid.NewString()
				c.Request().Header.Set(requestIDHeader, rid)
			}
			c.Set(requestIDKey, rid)
			c.Response().Header().Set(requestIDHeader, rid)
			return next(c)
		}
	}
}

func Observability(logger *slog.Logger, m *obs.Metrics) echo.MiddlewareFunc {
	return middleware.RequestLoggerWithConfig(middleware.RequestLoggerConfig{
		LogStatus:       true,
		LogResponseSize: true,
		LogLatency:      true,
		LogMethod:       true,
		LogURIPath:      true,
		LogRoutePath:    true,
		LogRequestID:    true,
		LogRemoteIP:     true,
		LogUserAgent:    true,
		HandleError:     true,
		LogValuesFunc: func(c *echo.Context, v middleware.RequestLoggerValues) error {
			level := slog.LevelInfo
			switch {
			case v.Status >= 500:
				level = slog.LevelError
			case v.Status >= 400:
				level = slog.LevelWarn
			}

			attrs := []slog.Attr{
				slog.String("request_id", v.RequestID),
				slog.String("method", v.Method),
				slog.String("route", v.RoutePath),
				slog.String("path", v.URIPath),
				slog.Int("status", v.Status),
				slog.Int64("latency_ms", v.Latency.Milliseconds()),
				slog.Int64("bytes_out", v.ResponseSize),
				slog.String("remote_ip", v.RemoteIP),
				slog.String("user_agent", v.UserAgent),
			}
			if v.Error != nil {
				attrs = append(attrs, slog.Any("error", v.Error))
			}
			logger.LogAttrs(c.Request().Context(), level, "http_request", attrs...)

			route := v.RoutePath
			if route == "" {
				route = "unmatched"
			}
			status := strconv.Itoa(v.Status)
			m.RequestsTotal.WithLabelValues(route, v.Method, status).Inc()
			m.RequestDuration.WithLabelValues(route, v.Method).Observe(v.Latency.Seconds())

			return nil
		},
	})
}

func OTelTracing(serviceName string) echo.MiddlewareFunc {
	tracer := otel.Tracer(otelTracerName)
	propagator := otel.GetTextMapPropagator()
	if propagator == nil {
		propagator = propagation.TraceContext{}
	}

	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c *echo.Context) error {
			req := c.Request()
			ctx := propagator.Extract(req.Context(), propagation.HeaderCarrier(req.Header))

			route := c.Path()
			spanName := req.Method + " " + route
			if route == "" {
				spanName = req.Method
			}

			ctx, span := tracer.Start(ctx, spanName,
				trace.WithSpanKind(trace.SpanKindServer),
				trace.WithAttributes(
					semconv.HTTPRequestMethodKey.String(req.Method),
					semconv.URLPath(req.URL.Path),
					semconv.HTTPRoute(route),
					semconv.UserAgentOriginal(req.UserAgent()),
					attribute.String("service.name", serviceName),
				),
			)
			defer span.End()

			c.SetRequest(req.WithContext(ctx))

			err := next(c)
			if err != nil {
				span.RecordError(err)
			}
			return err
		}
	}
}

var _ context.Context = context.Background()
