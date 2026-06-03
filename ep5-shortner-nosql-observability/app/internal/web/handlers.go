package web

import (
	"embed"
	"errors"
	"io/fs"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/a-h/templ"
	"github.com/labstack/echo/v5"

	"shortner-app/internal/obs"
	"shortner-app/internal/shortener"
	"shortner-app/internal/storage"
	"shortner-app/templates"
)

type Handlers struct {
	Service    *shortener.Service
	DefaultTTL time.Duration
	Metrics    *obs.Metrics
	Logger     *slog.Logger
}

func (h *Handlers) Register(e *echo.Echo, staticFS embed.FS) error {
	e.GET("/", h.home)
	e.POST("/shorten", h.shorten)
	e.GET("/r/:slug", h.redirect)
	e.GET("/stats/:slug", h.stats)
	e.GET("/clicks/:slug", h.clicks)
	e.GET("/admin", h.admin)
	e.GET("/health", h.health)

	e.GET("/metrics", echo.WrapHandler(h.Metrics.Handler()))

	sub, err := fs.Sub(staticFS, "static")
	if err != nil {
		return err
	}
	e.StaticFS("/static", sub)
	return nil
}

func render(c *echo.Context, status int, comp templ.Component) error {
	c.Response().Header().Set(echo.HeaderContentType, echo.MIMETextHTMLCharsetUTF8)
	c.Response().WriteHeader(status)
	return comp.Render(c.Request().Context(), c.Response())
}

func (h *Handlers) home(c *echo.Context) error {
	ctx := c.Request().Context()
	recent, err := h.Service.Recent(ctx, 10)
	if err != nil {
		h.logErr(c, "recent links lookup failed", err)
		return echo.NewHTTPError(http.StatusInternalServerError, "failed to load recent links")
	}
	return render(c, http.StatusOK, templates.Layout("Home", templates.Home(recent, h.DefaultTTL)))
}

func (h *Handlers) shorten(c *echo.Context) error {
	ctx := c.Request().Context()

	rawURL := strings.TrimSpace(c.FormValue("url"))
	ttlStr := strings.TrimSpace(c.FormValue("ttl"))

	var ttl time.Duration
	if ttlStr != "" {
		parsed, err := time.ParseDuration(ttlStr)
		if err != nil {
			return c.HTML(http.StatusBadRequest,
				`<div class="error" role="alert">Invalid TTL — use Go duration syntax, e.g. 24h.</div>`)
		}
		ttl = parsed
	}

	link, err := h.Service.Shorten(ctx, rawURL, ttl)
	switch {
	case errors.Is(err, shortener.ErrInvalidURL):
		return c.HTML(http.StatusBadRequest,
			`<div class="error" role="alert">Please supply a valid URL (including scheme).</div>`)
	case err != nil:
		h.logErr(c, "shorten failed", err)
		return c.HTML(http.StatusInternalServerError,
			`<div class="error" role="alert">Could not create short link. Try again.</div>`)
	}

	h.Metrics.LinksCreatedTotal.Inc()
	return render(c, http.StatusOK, templates.LinkRow(link))
}

func (h *Handlers) redirect(c *echo.Context) error {
	ctx := c.Request().Context()
	slug := c.Param("slug")

	link, err := h.Service.Resolve(ctx, slug)
	switch {
	case errors.Is(err, storage.ErrNotFound):
		h.Metrics.RedirectsTotal.WithLabelValues("not_found").Inc()
		return render(c, http.StatusNotFound, templates.Layout("Not found",
			templates.LinkError("Link not found",
				"That short link doesn't exist. Double-check the URL or head back home to create a new one.")))
	case errors.Is(err, storage.ErrExpired):
		h.Metrics.RedirectsTotal.WithLabelValues("expired").Inc()
		return render(c, http.StatusGone, templates.Layout("Expired",
			templates.LinkError("Link expired",
				"That short link has passed its expiration date and is no longer active.")))
	case err != nil:
		h.logErr(c, "resolve failed", err)
		return echo.NewHTTPError(http.StatusInternalServerError, "failed to resolve link")
	}

	// Best-effort click recording — failure should not block the redirect.
	if _, err := h.Service.RecordClick(ctx, slug); err != nil {
		h.logErr(c, "record click failed", err)
	}

	h.Metrics.RedirectsTotal.WithLabelValues("ok").Inc()
	return c.Redirect(http.StatusFound, link.URL)
}

func (h *Handlers) clicks(c *echo.Context) error {
	ctx := c.Request().Context()
	slug := c.Param("slug")

	link, err := h.Service.Resolve(ctx, slug)
	switch {
	case errors.Is(err, storage.ErrNotFound):
		return c.String(http.StatusOK, "—")
	case errors.Is(err, storage.ErrExpired):
		return c.String(http.StatusOK, "—")
	case err != nil:
		h.logErr(c, "clicks lookup failed", err)
		return c.String(http.StatusInternalServerError, "—")
	}
	return c.String(http.StatusOK, strconv.FormatInt(link.ClickCount, 10))
}

func (h *Handlers) stats(c *echo.Context) error {
	ctx := c.Request().Context()
	slug := c.Param("slug")

	link, err := h.Service.Resolve(ctx, slug)
	switch {
	case errors.Is(err, storage.ErrNotFound):
		return render(c, http.StatusNotFound, templates.Layout("Not found",
			templates.LinkError("Link not found",
				"That short link doesn't exist. Double-check the URL or head back home to create a new one.")))
	case errors.Is(err, storage.ErrExpired):
		return render(c, http.StatusGone, templates.Layout("Expired",
			templates.LinkError("Link expired",
				"That short link has passed its expiration date and is no longer active.")))
	case err != nil:
		h.logErr(c, "stats lookup failed", err)
		return echo.NewHTTPError(http.StatusInternalServerError, "failed to load stats")
	}
	return render(c, http.StatusOK, templates.Layout("Stats", templates.Stats(link)))
}

func (h *Handlers) admin(c *echo.Context) error {
	ctx := c.Request().Context()
	links, err := h.Service.Recent(ctx, 100)
	if err != nil {
		h.logErr(c, "admin recent failed", err)
		return echo.NewHTTPError(http.StatusInternalServerError, "failed to load admin view")
	}
	return render(c, http.StatusOK, templates.Layout("Admin", templates.Admin(links)))
}

func (h *Handlers) health(c *echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{"status": "ok"})
}

func (h *Handlers) logErr(c *echo.Context, msg string, err error) {
	if h.Logger == nil {
		return
	}
	rid, _ := c.Get(requestIDKey).(string)
	h.Logger.LogAttrs(c.Request().Context(), slog.LevelError, msg,
		slog.String("request_id", rid),
		slog.String("route", c.Path()),
		slog.Any("error", err),
	)
}
