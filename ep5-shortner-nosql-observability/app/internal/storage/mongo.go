package storage

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

type MongoStore struct {
	client *mongo.Client
	coll   *mongo.Collection
}

type mongoDoc struct {
	ID         string     `bson:"_id"`
	Slug       string     `bson:"slug"`
	URL        string     `bson:"url"`
	CreatedAt  time.Time  `bson:"created_at"`
	ExpiresAt  *time.Time `bson:"expires_at,omitempty"`
	ClickCount int64      `bson:"click_count"`
}

func NewMongoStore(ctx context.Context, uri, dbName, collName, caPEM string) (*MongoStore, error) {
	if uri == "" {
		return nil, errors.New("mongodb uri is required")
	}
	if dbName == "" || collName == "" {
		return nil, errors.New("mongodb database and collection are required")
	}
	clientOpts := options.Client().ApplyURI(uri)
	if caPEM != "" {
		pool := x509.NewCertPool()
		if !pool.AppendCertsFromPEM([]byte(caPEM)) {
			return nil, errors.New("mongodb tls ca: no certs parsed from PEM")
		}
		clientOpts.SetTLSConfig(&tls.Config{RootCAs: pool, MinVersion: tls.VersionTLS12})
	}
	client, err := mongo.Connect(clientOpts)
	if err != nil {
		return nil, fmt.Errorf("connect mongo: %w", err)
	}
	if err := client.Ping(ctx, nil); err != nil {
		_ = client.Disconnect(ctx)
		return nil, fmt.Errorf("ping mongo: %w", err)
	}
	coll := client.Database(dbName).Collection(collName)

	if _, err := coll.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "slug", Value: 1}},
		Options: options.Index().SetUnique(true).SetName("slug_unique"),
	}); err != nil {
		_ = client.Disconnect(ctx)
		return nil, fmt.Errorf("create slug index: %w", err)
	}
	if _, err := coll.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "expires_at", Value: 1}},
		Options: options.Index().SetExpireAfterSeconds(0).SetName("expires_at_ttl"),
	}); err != nil {
		_ = client.Disconnect(ctx)
		return nil, fmt.Errorf("create ttl index: %w", err)
	}

	return &MongoStore{client: client, coll: coll}, nil
}

func (s *MongoStore) Save(ctx context.Context, link Link) error {
	doc := linkToDoc(link)
	if _, err := s.coll.InsertOne(ctx, doc); err != nil {
		return fmt.Errorf("mongo insert: %w", err)
	}
	return nil
}

func (s *MongoStore) GetBySlug(ctx context.Context, slug string) (Link, error) {
	var doc mongoDoc
	err := s.coll.FindOne(ctx, bson.M{"slug": slug}).Decode(&doc)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return Link{}, ErrNotFound
		}
		return Link{}, fmt.Errorf("mongo find: %w", err)
	}
	link := docToLink(doc)
	if !link.ExpiresAt.IsZero() && time.Now().After(link.ExpiresAt) {
		return Link{}, ErrExpired
	}
	return link, nil
}

func (s *MongoStore) IncrementClicks(ctx context.Context, slug string) (int64, error) {
	opts := options.FindOneAndUpdate().SetReturnDocument(options.After)
	var doc mongoDoc
	err := s.coll.FindOneAndUpdate(
		ctx,
		bson.M{"slug": slug},
		bson.M{"$inc": bson.M{"click_count": 1}},
		opts,
	).Decode(&doc)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return 0, ErrNotFound
		}
		return 0, fmt.Errorf("mongo find-and-update: %w", err)
	}
	return doc.ClickCount, nil
}

func (s *MongoStore) List(ctx context.Context, limit int) ([]Link, error) {
	opts := options.Find().SetSort(bson.D{{Key: "_id", Value: -1}})
	if limit > 0 {
		opts = opts.SetLimit(int64(limit))
	}
	cur, err := s.coll.Find(ctx, bson.M{}, opts)
	if err != nil {
		return nil, fmt.Errorf("mongo find: %w", err)
	}
	defer cur.Close(ctx)

	var docs []mongoDoc
	if err := cur.All(ctx, &docs); err != nil {
		return nil, fmt.Errorf("mongo cursor: %w", err)
	}
	now := time.Now()
	links := make([]Link, 0, len(docs))
	for _, d := range docs {
		l := docToLink(d)
		if !l.ExpiresAt.IsZero() && now.After(l.ExpiresAt) {
			continue
		}
		links = append(links, l)
	}
	return links, nil
}

func (s *MongoStore) Close(ctx context.Context) error {
	if s.client == nil {
		return nil
	}
	return s.client.Disconnect(ctx)
}

func linkToDoc(link Link) mongoDoc {
	doc := mongoDoc{
		ID:         link.ID,
		Slug:       link.Slug,
		URL:        link.URL,
		CreatedAt:  link.CreatedAt.UTC(),
		ClickCount: link.ClickCount,
	}
	if !link.ExpiresAt.IsZero() {
		t := link.ExpiresAt.UTC()
		doc.ExpiresAt = &t
	}
	return doc
}

func docToLink(doc mongoDoc) Link {
	link := Link{
		ID:         doc.ID,
		Slug:       doc.Slug,
		URL:        doc.URL,
		CreatedAt:  doc.CreatedAt,
		ClickCount: doc.ClickCount,
	}
	if doc.ExpiresAt != nil {
		link.ExpiresAt = *doc.ExpiresAt
	}
	return link
}
