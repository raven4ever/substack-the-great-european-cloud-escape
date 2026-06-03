package web

import (
	"log/slog"
	"math/rand/v2"
	"net/http"

	"github.com/labstack/echo/v5"

	"shortner-app/internal/obs"
)

const redirectRoute = "/r/:slug"

func Chaos(rate float64, m *obs.Metrics, logger *slog.Logger) echo.MiddlewareFunc {
	if rate <= 0 {
		// No-op middleware — keeps wiring in main.go uniform.
		return func(next echo.HandlerFunc) echo.HandlerFunc {
			return next
		}
	}
	if rate > 1 {
		rate = 1
	}

	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c *echo.Context) error {
			if c.Path() != redirectRoute {
				return next(c)
			}
			if rand.Float64() >= rate {
				return next(c)
			}

			m.ChaosErrors.Inc()

			rid, _ := c.Get(requestIDKey).(string)
			logger.LogAttrs(c.Request().Context(), slog.LevelWarn, "chaos injection fired",
				slog.String("kind", "chaos"),
				slog.String("request_id", rid),
				slog.String("slug", c.Param("slug")),
				slog.Float64("rate", rate),
			)

			return echo.NewHTTPError(http.StatusInternalServerError, "synthetic chaos failure")
		}
	}
}
