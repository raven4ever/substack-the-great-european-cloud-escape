# IAM-based Grafana auth via X-Auth-Token header (Scaleway IAM proxy pattern).
# Grafana provider runs in anonymous mode; Scaleway IAM authenticates each request.
resource "scaleway_iam_application" "grafana" {
  name = format("%s-grafana", local.app_name)
  tags = [local.project]
}

resource "scaleway_iam_policy" "grafana" {
  name           = format("%s-grafana", local.app_name)
  application_id = scaleway_iam_application.grafana.id

  rule {
    organization_id      = scaleway_iam_application.grafana.organization_id
    permission_set_names = ["ObservabilityFullAccess"]
  }
}

resource "scaleway_iam_api_key" "grafana" {
  application_id = scaleway_iam_application.grafana.id
  description    = "Terraform → Cockpit Grafana via X-Auth-Token"
  expires_at     = time_rotating.iam_keys.rotation_rfc3339
}

# Per-project Cockpit Grafana endpoint URL.
data "scaleway_cockpit_grafana" "main" {}

# Mimir metric names for serverless containers:
#   serverless_container_cpu_seconds_total       (counter)
#   serverless_container_memory_working_set_bytes (gauge)
# Both labeled `resource_name`. Discovery: `{__name__=~".+container.+(cpu|memory).+"}`.
locals {
  dashboard_uid    = local.app_name
  dashboard_title  = format("%s observability", local.app_name)
  loki_uid         = format("Scaleway Logs - %s", data.scaleway_config.current.region)
  mimir_uid        = format("Scaleway Metrics - %s", data.scaleway_config.current.region)
  log_stream_label = format("{resource_name=\"%s\"}", local.app_name)

  dashboard_panels = [
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

    # count_over_time (not rate) — units match AWS sum(is_*) per 1m bin.
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
      targets = [
        {
          refId        = "A"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"kind\\\":\\\"chaos\" [1m]))", local.log_stream_label)
          legendFormat = "chaos"
        },
      ]
    },

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
      targets = [
        {
          refId        = "A"
          datasource   = { type = "loki", uid = local.loki_uid }
          expr         = format("sum(count_over_time(%s |= \"kind\\\":\\\"cold_start\" [5m]))", local.log_stream_label)
          legendFormat = "cold_starts"
        },
      ]
    },

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
