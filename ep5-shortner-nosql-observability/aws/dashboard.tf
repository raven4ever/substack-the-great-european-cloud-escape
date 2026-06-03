# CloudWatch dashboard mirroring the panel set the parallel Scaleway agent
# is shipping. Each widget body is built via jsonencode() so plan/apply
# diffs stay readable instead of devolving into a single heredoc blob.

locals {
  dashboard_log_group = aws_cloudwatch_log_group.app.name
  dashboard_region    = data.aws_region.current.id
  dashboard_cluster   = aws_ecs_cluster.app.name
  dashboard_service   = aws_ecs_express_gateway_service.app.service_name

  dashboard_widgets = [
    # Title banner ----------------------------------------------------------
    {
      type   = "text"
      x      = 0
      y      = 0
      width  = 24
      height = 2
      properties = {
        markdown = "# ep5-shortner — observability\nAWS / CloudWatch / ECS Express Mode + DynamoDB"
      }
    },

    # Row 1 -----------------------------------------------------------------
    # Panel 1: Requests per second by route
    # `count() / 60` over a 1m bin yields requests-per-second so the chart's
    # Y-axis matches the Scaleway dashboard's Loki rate() output.
    {
      type   = "log"
      x      = 0
      y      = 2
      width  = 8
      height = 6
      properties = {
        title   = "Requests per second by route"
        region  = local.dashboard_region
        view    = "timeSeries"
        stacked = false
        query = format(
          "SOURCE '%s' | fields @timestamp, route\n| filter msg = \"http_request\"\n| stats count() / 60 as rps by route, bin(1m)",
          local.dashboard_log_group,
        )
      }
    },

    # Panel 2: Latency p50 / p95 / p99 — /r/:slug
    {
      type   = "log"
      x      = 8
      y      = 2
      width  = 8
      height = 6
      properties = {
        title   = "Latency p50 / p95 / p99 — /r/:slug"
        region  = local.dashboard_region
        view    = "timeSeries"
        stacked = false
        query = format(
          "SOURCE '%s' | fields @timestamp, latency_ms\n| filter msg = \"http_request\" and route = \"/r/:slug\"\n| stats pct(latency_ms, 50) as p50, pct(latency_ms, 95) as p95, pct(latency_ms, 99) as p99 by bin(1m)",
          local.dashboard_log_group,
        )
      }
    },

    # Panel 3: HTTP status distribution
    # Logs Insights doesn't support C-ternary inside `stats ... by`, so we
    # synthesize per-class boolean fields up front and sum them. Each boolean
    # evaluates to 1/0 in the result set, so sum() gives the per-class count
    # per 1m bin (count units, matches Scaleway's count_over_time output).
    {
      type   = "log"
      x      = 16
      y      = 2
      width  = 8
      height = 6
      properties = {
        title   = "HTTP status distribution"
        region  = local.dashboard_region
        view    = "timeSeries"
        stacked = true
        query = format(
          "SOURCE '%s' | fields @timestamp,\n    (status >= 200 and status < 300) as is_2xx,\n    (status >= 300 and status < 400) as is_3xx,\n    (status >= 400 and status < 500) as is_4xx,\n    (status >= 500 and status < 600) as is_5xx\n| filter msg = \"http_request\"\n| stats sum(is_2xx) as `2xx`, sum(is_3xx) as `3xx`, sum(is_4xx) as `4xx`, sum(is_5xx) as `5xx` by bin(1m)",
          local.dashboard_log_group,
        )
      }
    },

    # Row 2 -----------------------------------------------------------------
    # Panel 4: Redirect outcomes
    # Same boolean-field workaround as panel 3 — Logs Insights can't ternary
    # inside `stats ... by`. Counts per 1m bin (matches Scaleway count_over_time).
    {
      type   = "log"
      x      = 0
      y      = 8
      width  = 8
      height = 6
      properties = {
        title   = "Redirect outcomes"
        region  = local.dashboard_region
        view    = "timeSeries"
        stacked = true
        query = format(
          "SOURCE '%s' | fields @timestamp,\n    (status = 302) as is_ok,\n    (status = 404) as is_not_found,\n    (status = 410) as is_expired\n| filter msg = \"http_request\" and route = \"/r/:slug\"\n| stats sum(is_ok) as ok, sum(is_not_found) as not_found, sum(is_expired) as expired by bin(1m)",
          local.dashboard_log_group,
        )
      }
    },

    # Panel 7: Chaos injections fired
    {
      type   = "log"
      x      = 8
      y      = 8
      width  = 8
      height = 6
      properties = {
        title   = "Chaos injections fired"
        region  = local.dashboard_region
        view    = "timeSeries"
        stacked = false
        query = format(
          "SOURCE '%s' | fields @timestamp\n| filter kind = \"chaos\"\n| stats count() as chaos_count by bin(1m)",
          local.dashboard_log_group,
        )
      }
    },

    # Panel 11: Links created rate
    # `count() / 60` over 1m bin → links/sec (matches Scaleway's rate() output).
    {
      type   = "log"
      x      = 16
      y      = 8
      width  = 8
      height = 6
      properties = {
        title   = "Links created rate"
        region  = local.dashboard_region
        view    = "timeSeries"
        stacked = false
        query = format(
          "SOURCE '%s' | fields @timestamp\n| filter msg = \"http_request\" and route = \"/shorten\" and status = 200\n| stats count() / 60 as links_per_sec by bin(1m)",
          local.dashboard_log_group,
        )
      }
    },

    # Row 3 -----------------------------------------------------------------
    # Panel 8: Cold starts (24h)
    {
      type   = "log"
      x      = 0
      y      = 14
      width  = 8
      height = 6
      properties = {
        title   = "Cold starts (24h)"
        region  = local.dashboard_region
        view    = "timeSeries"
        stacked = false
        period  = 86400
        query = format(
          "SOURCE '%s' | fields @timestamp\n| filter kind = \"cold_start\"\n| stats count() as cold_starts by bin(5m)",
          local.dashboard_log_group,
        )
      }
    },

    # Panel 9: Container CPU utilization
    {
      type   = "metric"
      x      = 8
      y      = 14
      width  = 8
      height = 6
      properties = {
        title  = "Container CPU utilization"
        region = local.dashboard_region
        view   = "timeSeries"
        stat   = "Average"
        period = 60
        metrics = [
          [
            "AWS/ECS",
            "CPUUtilization",
            "ClusterName",
            local.dashboard_cluster,
            "ServiceName",
            local.dashboard_service,
          ],
        ]
      }
    },

    # Panel 10: Container memory utilization
    {
      type   = "metric"
      x      = 16
      y      = 14
      width  = 8
      height = 6
      properties = {
        title  = "Container memory utilization"
        region = local.dashboard_region
        view   = "timeSeries"
        stat   = "Average"
        period = 60
        metrics = [
          [
            "AWS/ECS",
            "MemoryUtilization",
            "ClusterName",
            local.dashboard_cluster,
            "ServiceName",
            local.dashboard_service,
          ],
        ]
      }
    },

    # Row 4 -----------------------------------------------------------------
    # Panel 6: Heartbeat liveness (last 5m) — table acts as single-stat
    {
      type   = "log"
      x      = 0
      y      = 20
      width  = 8
      height = 4
      properties = {
        title  = "Heartbeat liveness (last 5m)"
        region = local.dashboard_region
        view   = "table"
        # 5 minutes in seconds, matches CloudWatch's relative time window.
        period = 300
        query = format(
          "SOURCE '%s' | fields @timestamp\n| filter kind = \"heartbeat\"\n| stats count() as heartbeats",
          local.dashboard_log_group,
        )
      }
    },

    # Panel 5: Recent error-level logs (full-width table to the right)
    {
      type   = "log"
      x      = 8
      y      = 20
      width  = 16
      height = 4
      properties = {
        title  = "Recent error-level logs"
        region = local.dashboard_region
        view   = "table"
        query = format(
          "SOURCE '%s' | fields @timestamp, level, msg, error, request_id, route\n| filter level = \"ERROR\"\n| sort @timestamp desc\n| limit 50",
          local.dashboard_log_group,
        )
      }
    },
  ]
}

resource "aws_cloudwatch_dashboard" "app" {
  dashboard_name = local.app_name

  # `start = "-PT1H"` and `periodOverride = "auto"` make the default view a
  # rolling 1-hour window with auto-resolution, matching Scaleway's
  # `time = { from = "now-1h" }` and `refresh = "30s"`.
  dashboard_body = jsonencode({
    start          = "-PT1H"
    periodOverride = "auto"
    widgets        = local.dashboard_widgets
  })
}
