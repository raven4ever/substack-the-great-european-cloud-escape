package obs

import (
	"context"
	"log/slog"
	"strings"
	"time"
)

func StartHeartbeat(ctx context.Context, logger *slog.Logger, interval time.Duration, payloadKB int) {
	if interval <= 0 || payloadKB == 0 {
		return
	}
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	padding := strings.Repeat("x", payloadKB*1024)
	var counter uint64

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			counter++
			logger.LogAttrs(ctx, slog.LevelInfo, "heartbeat",
				slog.String("kind", "heartbeat"),
				slog.Uint64("seq", counter),
				slog.String("padding", padding),
			)
		}
	}
}
