package storage

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"time"

	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

type DynamoStore struct {
	client *dynamodb.Client
	table  string
}


type dynamoItem struct {
	Slug       string `dynamodbav:"slug"`
	ID         string `dynamodbav:"id"`
	URL        string `dynamodbav:"url"`
	CreatedAt  string `dynamodbav:"created_at"`
	ExpiresAt  int64  `dynamodbav:"expires_at,omitempty"`
	ClickCount int64  `dynamodbav:"click_count"`
}

func NewDynamoStore(ctx context.Context, table, region string) (*DynamoStore, error) {
	if table == "" {
		return nil, errors.New("dynamodb table name is required")
	}
	opts := []func(*awsconfig.LoadOptions) error{}
	if region != "" {
		opts = append(opts, awsconfig.WithRegion(region))
	}
	cfg, err := awsconfig.LoadDefaultConfig(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}
	return &DynamoStore{
		client: dynamodb.NewFromConfig(cfg),
		table:  table,
	}, nil
}

func (s *DynamoStore) Save(ctx context.Context, link Link) error {
	item := dynamoItem{
		Slug:       link.Slug,
		ID:         link.ID,
		URL:        link.URL,
		CreatedAt:  link.CreatedAt.UTC().Format(time.RFC3339),
		ClickCount: link.ClickCount,
	}
	if !link.ExpiresAt.IsZero() {
		item.ExpiresAt = link.ExpiresAt.Unix()
	}
	av, err := attributevalue.MarshalMap(item)
	if err != nil {
		return fmt.Errorf("marshal dynamo item: %w", err)
	}
	if _, err := s.client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: &s.table,
		Item:      av,
	}); err != nil {
		return fmt.Errorf("dynamo put: %w", err)
	}
	return nil
}

func (s *DynamoStore) GetBySlug(ctx context.Context, slug string) (Link, error) {
	out, err := s.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: &s.table,
		Key: map[string]types.AttributeValue{
			"slug": &types.AttributeValueMemberS{Value: slug},
		},
	})
	if err != nil {
		return Link{}, fmt.Errorf("dynamo get: %w", err)
	}
	if len(out.Item) == 0 {
		return Link{}, ErrNotFound
	}
	var item dynamoItem
	if err := attributevalue.UnmarshalMap(out.Item, &item); err != nil {
		return Link{}, fmt.Errorf("unmarshal dynamo item: %w", err)
	}
	link := itemToLink(item)
	if item.ExpiresAt > 0 && time.Now().After(link.ExpiresAt) {
		return Link{}, ErrExpired
	}
	return link, nil
}

func (s *DynamoStore) IncrementClicks(ctx context.Context, slug string) (int64, error) {
	update := "ADD click_count :one"
	condition := "attribute_exists(slug)"
	out, err := s.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: &s.table,
		Key: map[string]types.AttributeValue{
			"slug": &types.AttributeValueMemberS{Value: slug},
		},
		UpdateExpression:    &update,
		ConditionExpression: &condition,
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":one": &types.AttributeValueMemberN{Value: "1"},
		},
		ReturnValues: types.ReturnValueUpdatedNew,
	})
	if err != nil {
		var ccfe *types.ConditionalCheckFailedException
		if errors.As(err, &ccfe) {
			return 0, ErrNotFound
		}
		return 0, fmt.Errorf("dynamo update: %w", err)
	}
	raw, ok := out.Attributes["click_count"].(*types.AttributeValueMemberN)
	if !ok {
		return 0, errors.New("dynamo update: missing click_count in response")
	}
	n, err := strconv.ParseInt(raw.Value, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("parse click_count: %w", err)
	}
	return n, nil
}

func (s *DynamoStore) List(ctx context.Context, limit int) ([]Link, error) {
	in := &dynamodb.ScanInput{TableName: &s.table}
	if limit > 0 {
		l := int32(limit)
		in.Limit = &l
	}
	out, err := s.client.Scan(ctx, in)
	if err != nil {
		return nil, fmt.Errorf("dynamo scan: %w", err)
	}
	now := time.Now()
	links := make([]Link, 0, len(out.Items))
	for _, raw := range out.Items {
		var item dynamoItem
		if err := attributevalue.UnmarshalMap(raw, &item); err != nil {
			return nil, fmt.Errorf("unmarshal dynamo item: %w", err)
		}
		link := itemToLink(item)
		if item.ExpiresAt > 0 && now.After(link.ExpiresAt) {
			continue
		}
		links = append(links, link)
	}
	return links, nil
}

func (s *DynamoStore) Close(_ context.Context) error {
	return nil
}

func itemToLink(item dynamoItem) Link {
	link := Link{
		ID:         item.ID,
		Slug:       item.Slug,
		URL:        item.URL,
		ClickCount: item.ClickCount,
	}
	if t, err := time.Parse(time.RFC3339, item.CreatedAt); err == nil {
		link.CreatedAt = t
	}
	if item.ExpiresAt > 0 {
		link.ExpiresAt = time.Unix(item.ExpiresAt, 0).UTC()
	}
	return link
}
