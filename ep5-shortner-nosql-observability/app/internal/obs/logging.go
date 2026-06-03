package obs

import (
	"log/slog"
	"os"

	"shortner-app/internal/config"
)

func NewLogger(cfg *config.Config) *slog.Logger {
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: cfg.LogLevel,
	})
	return slog.New(handler).With(
		slog.String("service", cfg.AppName),
		slog.String("version", cfg.Version),
	)
}
