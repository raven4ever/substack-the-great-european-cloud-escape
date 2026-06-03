package obs

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"shortner-app/internal/config"
)

type Metrics struct {
	Registry          *prometheus.Registry
	RequestsTotal     *prometheus.CounterVec
	RequestDuration   *prometheus.HistogramVec
	LinksCreatedTotal prometheus.Counter
	RedirectsTotal    *prometheus.CounterVec
	ChaosErrors       prometheus.Counter
}

func NewMetrics(_ *config.Config) *Metrics {
	reg := prometheus.NewRegistry()

	m := &Metrics{
		Registry: reg,
		RequestsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "http_requests_total",
				Help: "Total number of HTTP requests, partitioned by route, method, and status.",
			},
			[]string{"route", "method", "status"},
		),
		RequestDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "http_request_duration_seconds",
				Help:    "HTTP request latency in seconds, partitioned by route and method.",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"route", "method"},
		),
		LinksCreatedTotal: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "links_created_total",
			Help: "Total number of short links successfully created.",
		}),
		RedirectsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "redirects_total",
				Help: "Total number of redirect attempts, partitioned by outcome (ok, expired, not_found).",
			},
			[]string{"outcome"},
		),
		ChaosErrors: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "chaos_errors_total",
			Help: "Total number of errors injected by the chaos middleware.",
		}),
	}

	reg.MustRegister(
		collectors.NewGoCollector(),
		collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}),
		m.RequestsTotal,
		m.RequestDuration,
		m.LinksCreatedTotal,
		m.RedirectsTotal,
		m.ChaosErrors,
	)

	return m
}

func (m *Metrics) Handler() http.Handler {
	return promhttp.HandlerFor(m.Registry, promhttp.HandlerOpts{})
}
