variable "default_ttl" {
  description = "Default TTL for shortened links (Go duration string)."
  type        = string
  default     = "24h"
}

variable "log_level" {
  description = "Application log level (debug, info, warn, error)."
  type        = string
  default     = "info"
}

variable "app_version" {
  description = "Version string surfaced in logs and traces."
  type        = string
  default     = "ep5-aws"
}

variable "heartbeat_interval" {
  description = "Interval between heartbeat log lines (Go duration string)."
  type        = string
  default     = "10s"
}

variable "heartbeat_payload_kb" {
  description = "Padding size of each heartbeat log line, in kilobytes."
  type        = string
  default     = "5"
}

variable "chaos_rate" {
  description = "Probability (0..1) that a redirect returns a synthetic 500."
  type        = string
  default     = "0.01"
}
