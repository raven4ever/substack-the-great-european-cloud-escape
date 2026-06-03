package shortener

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"

	"shortner-app/internal/storage"
)

var ErrInvalidURL = errors.New("invalid url: must be a non-empty http(s) URL")

const tracerName = "shortener"

type Service struct {
	store      storage.Store
	defaultTTL time.Duration
	now        func() time.Time
}

func New(store storage.Store, defaultTTL time.Duration) *Service {
	return &Service{
		store:      store,
		defaultTTL: defaultTTL,
		now:        time.Now,
	}
}

func (s *Service) tracer() trace.Tracer {
	return otel.Tracer(tracerName)
}

func (s *Service) Shorten(ctx context.Context, rawURL string, ttl time.Duration) (storage.Link, error) {
	ctx, span := s.tracer().Start(ctx, "Service.Shorten")
	defer span.End()

	parsed, err := validateURL(rawURL)
	if err != nil {
		span.RecordError(err)
		return storage.Link{}, err
	}

	if ttl <= 0 {
		ttl = s.defaultTTL
	}

	id, err := NewID()
	if err != nil {
		span.RecordError(err)
		return storage.Link{}, fmt.Errorf("generate id: %w", err)
	}
	slug := SlugFromUUID(id)

	now := s.now()
	var expiresAt time.Time
	if ttl > 0 {
		expiresAt = now.Add(ttl)
	}

	link := storage.Link{
		ID:         id.String(),
		Slug:       slug,
		URL:        parsed.String(),
		CreatedAt:  now,
		ExpiresAt:  expiresAt,
		ClickCount: 0,
	}

	span.SetAttributes(
		attribute.String("slug", slug),
		attribute.String("url.host", parsed.Host),
		attribute.String("ttl", ttl.String()),
	)

	if err := s.store.Save(ctx, link); err != nil {
		span.RecordError(err)
		return storage.Link{}, fmt.Errorf("save link: %w", err)
	}
	return link, nil
}

func (s *Service) Resolve(ctx context.Context, slug string) (storage.Link, error) {
	ctx, span := s.tracer().Start(ctx, "Service.Resolve")
	defer span.End()
	span.SetAttributes(attribute.String("slug", slug))

	link, err := s.store.GetBySlug(ctx, slug)
	if err != nil {
		span.RecordError(err)
		return storage.Link{}, err
	}

	if !link.ExpiresAt.IsZero() && s.now().After(link.ExpiresAt) {
		span.RecordError(storage.ErrExpired)
		return storage.Link{}, storage.ErrExpired
	}
	if u, err := url.Parse(link.URL); err == nil {
		span.SetAttributes(attribute.String("url.host", u.Host))
	}
	return link, nil
}

func (s *Service) RecordClick(ctx context.Context, slug string) (int64, error) {
	return s.store.IncrementClicks(ctx, slug)
}

func (s *Service) Recent(ctx context.Context, limit int) ([]storage.Link, error) {
	links, err := s.store.List(ctx, limit)
	if err != nil {
		return nil, err
	}
	now := s.now()
	out := make([]storage.Link, 0, len(links))
	for _, l := range links {
		if !l.ExpiresAt.IsZero() && now.After(l.ExpiresAt) {
			continue
		}
		out = append(out, l)
	}
	return out, nil
}

func validateURL(rawURL string) (*url.URL, error) {
	if strings.TrimSpace(rawURL) == "" {
		return nil, ErrInvalidURL
	}
	u, err := url.Parse(rawURL)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidURL, err)
	}
	scheme := strings.ToLower(u.Scheme)
	if scheme != "http" && scheme != "https" {
		return nil, ErrInvalidURL
	}
	if u.Host == "" {
		return nil, ErrInvalidURL
	}
	return u, nil
}
