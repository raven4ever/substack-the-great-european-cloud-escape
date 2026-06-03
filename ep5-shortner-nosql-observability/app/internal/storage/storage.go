package storage

import (
	"context"
	"errors"
	"time"
)

var (
	ErrNotFound = errors.New("link not found")
	ErrExpired  = errors.New("link expired")
)

type Link struct {
	ID         string
	Slug       string
	URL        string
	CreatedAt  time.Time
	ExpiresAt  time.Time
	ClickCount int64
}

type Store interface {
	Save(ctx context.Context, link Link) error
	GetBySlug(ctx context.Context, slug string) (Link, error)
	IncrementClicks(ctx context.Context, slug string) (int64, error)
	List(ctx context.Context, limit int) ([]Link, error)
	Close(ctx context.Context) error
}
