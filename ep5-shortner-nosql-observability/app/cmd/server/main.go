package main

import (
	"context"
	"embed"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"

	"github.com/labstack/echo/v5"
	"github.com/labstack/echo/v5/middleware"

	"shortner-app/internal/config"
	"shortner-app/internal/obs"
	"shortner-app/internal/shortener"
	"shortner-app/internal/storage"
	"shortner-app/internal/web"
)

var staticFS embed.FS

func main() {
	ctx, rootCancel := context.WithCancel(context.Background())
	defer rootCancel()

	cfg, err := config.Load()
	if err != nil {
		slog.New(slog.NewJSONHandler(os.Stderr, nil)).Error("config load", "error", err)
		os.Exit(1)
	}

	logger := obs.NewLogger(cfg)
	slog.SetDefault(logger)

	logger.Info("cold start",
		"kind", "cold_start",
		"service", cfg.AppName,
		"version", cfg.Version,
		"storage_kind", cfg.StorageKind,
		"trace_exporter", cfg.TraceExporter,
	)

	tracerShutdown, err := obs.InitTracing(ctx, cfg)
	if err != nil {
		logger.Error("tracing init", "error", err)
		os.Exit(1)
	}

	metrics := obs.NewMetrics(cfg)

	store, err := storage.New(ctx, cfg)
	if err != nil {
		logger.Error("storage init", "error", err, "kind", cfg.StorageKind)
		os.Exit(1)
	}

	service := shortener.New(store, cfg.DefaultTTL)

	handlers := &web.Handlers{
		Service:    service,
		DefaultTTL: cfg.DefaultTTL,
		Metrics:    metrics,
		Logger:     logger,
	}

	e := echo.New()
	e.Logger = logger
	e.Use(middleware.Recover())
	e.Use(web.OTelTracing(cfg.AppName))
	e.Use(web.RequestID())
	e.Use(web.Observability(logger, metrics))
	e.Use(web.Chaos(cfg.ChaosRate, metrics, logger))

	if err := handlers.Register(e, staticFS); err != nil {
		logger.Error("route registration", "error", err)
		os.Exit(1)
	}

	go obs.StartHeartbeat(ctx, logger, cfg.HeartbeatInterval, cfg.HeartbeatPayloadKB)

	startErr := make(chan error, 1)
	go func() {
		addr := ":" + strconv.Itoa(cfg.Port)
		logger.Info("server listening", "addr", addr)
		sc := echo.StartConfig{
			Address:         addr,
			HideBanner:      true,
			HidePort:        true,
			GracefulTimeout: cfg.ShutdownTimeout,
		}
		if err := sc.Start(ctx, e); err != nil && !errors.Is(err, http.ErrServerClosed) && !errors.Is(err, context.Canceled) {
			startErr <- err
		}
		close(startErr)
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-sigCh:
		logger.Info("shutdown initiated", "signal", sig.String())
	case err := <-startErr:
		if err != nil {
			logger.Error("server start", "error", err)
		}
	}

	rootCancel()

	<-startErr

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()

	if err := tracerShutdown(shutdownCtx); err != nil {
		logger.Error("tracer shutdown", "error", err)
	}
	if err := store.Close(shutdownCtx); err != nil {
		logger.Error("store close", "error", err)
	}

	logger.Info("shutdown complete")
}
