package config

import (
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	AppName  string
	Version  string
	Port     int
	LogLevel slog.Level

	StorageKind       string
	DynamoDBTable     string
	DynamoDBRegion    string
	MongoDBURI        string
	MongoDBDatabase   string
	MongoDBCollection string

	DefaultTTL time.Duration

	TraceExporter string
	OTLPEndpoint  string
	OTLPHeaders   map[string]string
	OTLPInsecure  bool
	AWSRegion     string

	HeartbeatInterval  time.Duration
	HeartbeatPayloadKB int
	ChaosRate          float64
	ShutdownTimeout    time.Duration
}

func Load() (*Config, error) {
	cfg := &Config{
		AppName:            getStr("APP_NAME", "shortner"),
		Version:            getStr("APP_VERSION", "dev"),
		Port:               getInt("PORT", 8080),
		LogLevel:           parseLogLevel(getStr("LOG_LEVEL", "info")),
		StorageKind:        strings.ToLower(getStr("STORAGE_KIND", "mongodb")),
		DynamoDBTable:      getStr("DYNAMODB_TABLE", "shortner-links"),
		DynamoDBRegion:     getStr("DYNAMODB_REGION", ""),
		MongoDBURI:         getStr("MONGODB_URI", "mongodb://localhost:27017"),
		MongoDBDatabase:    getStr("MONGODB_DATABASE", "shortner"),
		MongoDBCollection:  getStr("MONGODB_COLLECTION", "links"),
		DefaultTTL:         getDuration("DEFAULT_TTL", 24*time.Hour),
		TraceExporter:      strings.ToLower(getStr("TRACE_EXPORTER", "none")),
		OTLPEndpoint:       getStr("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		OTLPHeaders:        parseHeaders(getStr("OTEL_EXPORTER_OTLP_HEADERS", "")),
		OTLPInsecure:       getBool("OTEL_EXPORTER_OTLP_INSECURE", false),
		AWSRegion:          getStr("AWS_REGION", ""),
		HeartbeatInterval:  getDuration("HEARTBEAT_INTERVAL", 10*time.Second),
		HeartbeatPayloadKB: getInt("HEARTBEAT_PAYLOAD_KB", 5),
		ChaosRate:          getFloat("CHAOS_RATE", 0.01),
		ShutdownTimeout:    getDuration("SHUTDOWN_TIMEOUT", 10*time.Second),
	}

	if cfg.StorageKind != "dynamodb" && cfg.StorageKind != "mongodb" {
		return nil, fmt.Errorf("STORAGE_KIND must be dynamodb or mongodb, got %q", cfg.StorageKind)
	}
	switch cfg.TraceExporter {
	case "none", "otlp", "xray":
	default:
		return nil, fmt.Errorf("TRACE_EXPORTER must be none, otlp, or xray, got %q", cfg.TraceExporter)
	}
	if cfg.TraceExporter == "xray" && cfg.AWSRegion == "" {
		return nil, fmt.Errorf("AWS_REGION is required when TRACE_EXPORTER=xray")
	}
	if cfg.TraceExporter != "none" && cfg.OTLPEndpoint == "" {
		return nil, fmt.Errorf("OTEL_EXPORTER_OTLP_ENDPOINT is required when TRACE_EXPORTER=%s", cfg.TraceExporter)
	}
	if cfg.ChaosRate < 0 || cfg.ChaosRate > 1 {
		return nil, fmt.Errorf("CHAOS_RATE must be between 0 and 1, got %v", cfg.ChaosRate)
	}
	if cfg.DefaultTTL <= 0 {
		return nil, fmt.Errorf("DEFAULT_TTL must be positive, got %v", cfg.DefaultTTL)
	}
	if cfg.HeartbeatPayloadKB < 0 {
		return nil, fmt.Errorf("HEARTBEAT_PAYLOAD_KB must be >= 0, got %d", cfg.HeartbeatPayloadKB)
	}

	return cfg, nil
}

func getStr(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

func getInt(key string, def int) int {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func getBool(key string, def bool) bool {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return def
}

func getFloat(key string, def float64) float64 {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
	}
	return def
}

func getDuration(key string, def time.Duration) time.Duration {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}

func parseLogLevel(s string) slog.Level {
	switch strings.ToLower(s) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

// parseHeaders parses "k1=v1,k2=v2" per OTEL_EXPORTER_OTLP_HEADERS convention.
func parseHeaders(s string) map[string]string {
	out := map[string]string{}
	if s == "" {
		return out
	}
	for _, pair := range strings.Split(s, ",") {
		kv := strings.SplitN(pair, "=", 2)
		if len(kv) != 2 {
			continue
		}
		k := strings.TrimSpace(kv[0])
		v := strings.TrimSpace(kv[1])
		if k != "" {
			out[k] = v
		}
	}
	return out
}
