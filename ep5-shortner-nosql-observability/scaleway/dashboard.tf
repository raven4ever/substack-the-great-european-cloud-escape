# Cockpit Grafana dashboard for ep5-shortner serverless container.
# Two-phase apply: Grafana provider auth = apply-time IAM key secret.
# Makefile runs `apply -target=scaleway_iam_api_key.grafana` first.

# IAM-based Cockpit auth. scaleway_cockpit_grafana_user removed Jan 2026.
# Scaleway now binds Grafana to IAM application via API key as bearer.
resource "scaleway_iam_application" "grafana" {
  name = format("%s-grafana", local.app_name)
  tags = [local.project]
}

resource "scaleway_iam_policy" "grafana" {
  name           = format("%s-grafana", local.app_name)
  application_id = scaleway_iam_application.grafana.id

  rule {
    organization_id      = scaleway_iam_application.grafana.organization_id
    permission_set_names = ["CockpitFullAccess"]
  }
}

resource "scaleway_iam_api_key" "grafana" {
  application_id = scaleway_iam_application.grafana.id
  description    = "Terraform → Cockpit Grafana provider auth"
  expires_at     = time_rotating.iam_keys.rotation_rfc3339
}

# Cockpit pre-provisions Loki + Mimir + Tempo as Grafana datasources.
# UIDs random, names stable: "Scaleway Metrics" (Mimir), "Scaleway Logs" (Loki).
data "grafana_data_source" "metrics" {
  name = "Scaleway Metrics"

  depends_on = [scaleway_iam_api_key.grafana]
}

data "grafana_data_source" "logs" {
  name = "Scaleway Logs"

  depends_on = [scaleway_iam_api_key.grafana]
}

# ---------------------------------------------------------------------------
# Dashboard model. Built as nested HCL maps and rendered through `jsonencode`
# so plan/apply diffs stay reviewable. 24-column grid, layout mirrors the
# parallel AWS CloudWatch dashboard for visual parity in the article.
#
# Container CPU / memory metric names
# -----------------------------------
# Scaleway does not publish a stable list of Mimir metric names for serverless
# containers. The Cockpit-bundled "Serverless Containers Overview" dashboard
# emits queries against names of the form
# `serverless_container_<dimension>_<unit>`; the closest matches discoverable
# via `{__name__=~".+container.+(cpu|memory).+"}` in Grafana Explore are:
#
#   - serverless_container_cpu_seconds_total       (counter — rate over 1m)
#   - serverless_container_memory_working_set_bytes (gauge)
#
# Both carry a `resource_name` label matching the container name. If your
# project shows different names, update the `expr` below; the queries are
# scoped to `resource_name="ep5-shortner"` so unrelated metrics are filtered
# out either way.
# ---------------------------------------------------------------------------
locals {
  dashboard_uid    = local.app_name
  dashboard_title  = format("%s observability", local.app_name)
  loki_uid         = data.grafana_data_source.logs.uid
  mimir_uid        = data.grafana_data_source.metrics.uid
  log_stream_label = format("{resource_name=\"%s\"}", local.app_name)

  dashboard_panels = [
    # ---- Title banner ----------------------------------------------------
    {
      id    = 100
      type  = "text"
      title = ""
      gridPos = {
        x = 0
        y = 0
        w = 24
        h = 2
      }
      options = {
        mode    = "markdown"
        content = format("# %s — observability\nScaleway / Cockpit (Grafana + Loki + Mimir + Tempo) / Serverless Containers + Managed MongoDB", local.app_name)
      }
    },

    # ---- Row 1 ----------------------------------------------------------
    # Panel 1: Requests per second by route
    {
      id    = 1
      type  = "timeseries"
      title = "Requests per second by route"
      gridPos = {
        x = 0
        y = 2
        w = 8
        h = 6
      }
      datasource = { type = "loki", uid = local.loki_uid }
      targets = [
        {
          refId        = "A"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum by (route) (rate(%s |= \"http_request\" | json [1m]))", local.log_stream_label)
          legendFormat = "{{route}}"
        },
      ]
    },

    # Panel 2: Latency p50 / p95 / p99 — /r/:slug
    {
      id    = 2
      type  = "timeseries"
      title = "Latency p50 / p95 / p99 — /r/:slug"
      gridPos = {
        x = 8
        y = 2
        w = 8
        h = 6
      }
      datasource = { type = "loki", uid = local.loki_uid }
      targets = [
        {
          refId        = "P50"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("quantile_over_time(0.50, %s |= \"http_request\" | json | route=\"/r/:slug\" | unwrap latency_ms [1m])", local.log_stream_label)
          legendFormat = "p50"
        },
        {
          refId        = "P95"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("quantile_over_time(0.95, %s |= \"http_request\" | json | route=\"/r/:slug\" | unwrap latency_ms [1m])", local.log_stream_label)
          legendFormat = "p95"
        },
        {
          refId        = "P99"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("quantile_over_time(0.99, %s |= \"http_request\" | json | route=\"/r/:slug\" | unwrap latency_ms [1m])", local.log_stream_label)
          legendFormat = "p99"
        },
      ]
    },

    # Panel 3: HTTP status distribution (stacked, one query per class)
    {
      id    = 3
      type  = "timeseries"
      title = "HTTP status distribution"
      gridPos = {
        x = 16
        y = 2
        w = 8
        h = 6
      }
      datasource = { type = "loki", uid = local.loki_uid }
      fieldConfig = {
        defaults = {
          custom = {
            stacking = { mode = "normal" }
          }
        }
      }
      # count_over_time, not rate, so units match the AWS sum(is_*) per 1m bin.
      targets = [
        {
          refId        = "A"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"http_request\" | json | status >= 200 and status < 300 [1m]))", local.log_stream_label)
          legendFormat = "2xx"
        },
        {
          refId        = "B"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"http_request\" | json | status >= 300 and status < 400 [1m]))", local.log_stream_label)
          legendFormat = "3xx"
        },
        {
          refId        = "C"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"http_request\" | json | status >= 400 and status < 500 [1m]))", local.log_stream_label)
          legendFormat = "4xx"
        },
        {
          refId        = "D"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"http_request\" | json | status >= 500 and status < 600 [1m]))", local.log_stream_label)
          legendFormat = "5xx"
        },
      ]
    },

    # ---- Row 2 ----------------------------------------------------------
    # Panel 4: Redirect outcomes (stacked)
    {
      id    = 4
      type  = "timeseries"
      title = "Redirect outcomes"
      gridPos = {
        x = 0
        y = 8
        w = 8
        h = 6
      }
      datasource = { type = "loki", uid = local.loki_uid }
      fieldConfig = {
        defaults = {
          custom = {
            stacking = { mode = "normal" }
          }
        }
      }
      # count_over_time, not rate, so units match the AWS sum(is_*) per 1m bin.
      targets = [
        {
          refId        = "OK"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"http_request\" | json | route=\"/r/:slug\" | status=302 [1m]))", local.log_stream_label)
          legendFormat = "ok"
        },
        {
          refId        = "NOT_FOUND"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"http_request\" | json | route=\"/r/:slug\" | status=404 [1m]))", local.log_stream_label)
          legendFormat = "not_found"
        },
        {
          refId        = "EXPIRED"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"http_request\" | json | route=\"/r/:slug\" | status=410 [1m]))", local.log_stream_label)
          legendFormat = "expired"
        },
      ]
    },

    # Panel 7: Chaos injections fired
    {
      id    = 7
      type  = "timeseries"
      title = "Chaos injections fired"
      gridPos = {
        x = 8
        y = 8
        w = 8
        h = 6
      }
      datasource = { type = "loki", uid = local.loki_uid }
      # count_over_time per 1m bin so the chart matches AWS's count() per 1m bin.
      targets = [
        {
          refId        = "A"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"kind\\\":\\\"chaos\" [1m]))", local.log_stream_label)
          legendFormat = "chaos"
        },
      ]
    },

    # Panel 11: Links created rate
    {
      id    = 11
      type  = "timeseries"
      title = "Links created rate"
      gridPos = {
        x = 16
        y = 8
        w = 8
        h = 6
      }
      datasource = { type = "loki", uid = local.loki_uid }
      targets = [
        {
          refId        = "A"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(rate(%s |= \"http_request\" | json | route=\"/shorten\" | status=200 [1m]))", local.log_stream_label)
          legendFormat = "links/s"
        },
      ]
    },

    # ---- Row 3 ----------------------------------------------------------
    # Panel 8: Cold starts (24h)
    {
      id    = 8
      type  = "timeseries"
      title = "Cold starts (24h)"
      gridPos = {
        x = 0
        y = 14
        w = 8
        h = 6
      }
      datasource = { type = "loki", uid = local.loki_uid }
      timeFrom   = "24h"
      # count_over_time per 5m bin so the chart matches AWS's count() per 5m bin.
      targets = [
        {
          refId        = "A"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"kind\\\":\\\"cold_start\" [5m]))", local.log_stream_label)
          legendFormat = "cold_starts"
        },
      ]
    },

    # Panel 9: Container CPU utilization (Mimir / Prometheus)
    {
      id    = 9
      type  = "timeseries"
      title = "Container CPU utilization"
      gridPos = {
        x = 8
        y = 14
        w = 8
        h = 6
      }
      datasource = { type = "prometheus", uid = local.mimir_uid }
      targets = [
        {
          refId        = "A"
          datasource   = { type = "prometheus", uid = local.mimir_uid }
          expr         = format("sum by (resource_name) (rate(serverless_container_cpu_seconds_total{resource_name=\"%s\"}[1m]))", local.app_name)
          legendFormat = "{{resource_name}}"
        },
      ]
    },

    # Panel 10: Container memory utilization (Mimir / Prometheus)
    {
      id    = 10
      type  = "timeseries"
      title = "Container memory utilization"
      gridPos = {
        x = 16
        y = 14
        w = 8
        h = 6
      }
      datasource = { type = "prometheus", uid = local.mimir_uid }
      targets = [
        {
          refId        = "A"
          datasource   = { type = "prometheus", uid = local.mimir_uid }
          expr         = format("sum by (resource_name) (serverless_container_memory_working_set_bytes{resource_name=\"%s\"})", local.app_name)
          legendFormat = "{{resource_name}}"
        },
      ]
    },

    # ---- Row 4 ----------------------------------------------------------
    # Panel 6: Heartbeat liveness (last 5m) — single stat
    {
      id    = 6
      type  = "stat"
      title = "Heartbeat liveness (last 5m)"
      gridPos = {
        x = 0
        y = 20
        w = 8
        h = 4
      }
      datasource = { type = "loki", uid = local.loki_uid }
      targets = [
        {
          refId        = "A"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"kind\\\":\\\"heartbeat\" [5m]))", local.log_stream_label)
          legendFormat = "heartbeats"
        },
      ]
      options = {
        reduceOptions = {
          calcs  = ["lastNotNull"]
          fields = ""
          values = false
        }
        colorMode   = "value"
        graphMode   = "area"
        textMode    = "auto"
        orientation = "auto"
      }
    },

    # Panel 5: Recent error-level logs (logs panel, full-width remainder)
    {
      id    = 5
      type  = "logs"
      title = "Recent error-level logs"
      gridPos = {
        x = 8
        y = 20
        w = 16
        h = 4
      }
      datasource = { type = "loki", uid = local.loki_uid }
      targets = [
        {
          refId      = "A"
          datasource = { type = "loki", uid = local.loki_uid }
          expr       = format("%s |= \"level\\\":\\\"ERROR\" | json", local.log_stream_label)
          maxLines   = 50
        },
      ]
      options = {
        showTime           = true
        showLabels         = false
        showCommonLabels   = false
        wrapLogMessage     = true
        prettifyLogMessage = false
        enableLogDetails   = true
        dedupStrategy      = "exact"
        sortOrder          = "Descending"
      }
    },
  ]

  dashboard_model = {
    uid           = local.dashboard_uid
    title         = local.dashboard_title
    schemaVersion = 38
    version       = 1
    refresh       = "30s"
    time = {
      from = "now-1h"
      to   = "now"
    }
    timezone = "browser"
    tags     = [local.project, "ep5", "shortner"]
    panels   = local.dashboard_panels
  }
}

resource "grafana_dashboard" "app" {
  config_json = jsonencode(local.dashboard_model)
  overwrite   = true
}
