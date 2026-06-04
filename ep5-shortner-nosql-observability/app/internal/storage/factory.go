package storage

import (
	"context"
	"fmt"

	"shortner-app/internal/config"
)

func New(ctx context.Context, cfg *config.Config) (Store, error) {
	if cfg == nil {
		return nil, fmt.Errorf("storage: nil config")
	}
	switch cfg.StorageKind {
	case "dynamodb":
		store, err := NewDynamoStore(ctx, cfg.DynamoDBTable, cfg.DynamoDBRegion)
		if err != nil {
			return nil, fmt.Errorf("init dynamodb: %w", err)
		}
		return store, nil
	case "mongodb":
		store, err := NewMongoStore(ctx, cfg.MongoDBURI, cfg.MongoDBDatabase, cfg.MongoDBCollection, cfg.MongoDBTLSCA)
		if err != nil {
			return nil, fmt.Errorf("init mongodb: %w", err)
		}
		return store, nil
	default:
		return nil, fmt.Errorf("storage: unknown StorageKind %q", cfg.StorageKind)
	}
}
