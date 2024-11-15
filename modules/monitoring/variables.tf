variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for Grafana ingress"
  type        = string
}

variable "grafana_admin_password" {
  description = "Password for Grafana admin user"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alerts"
  type        = string
  sensitive   = true
}

variable "pagerduty_routing_key" {
  description = "PagerDuty routing key for critical alerts"
  type        = string
  sensitive   = true
}

variable "grafana_url" {
  description = "External URL for Grafana"
  type        = string
}

variable "prometheus_storage_class" {
  description = "Storage class for Prometheus PVC"
  type        = string
  default     = "gp3"
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus PVC"
  type        = string
  default     = "50Gi"
}

variable "alertmanager_storage_size" {
  description = "Storage size for AlertManager PVC"
  type        = string
  default     = "10Gi"
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana PVC"
  type        = string
  default     = "10Gi"
}

variable "prometheus_retention_days" {
  description = "Number of days to retain Prometheus metrics"
  type        = number
  default     = 15
}

variable "alertmanager_retention_hours" {
  description = "Number of hours to retain AlertManager data"
  type        = number
  default     = 120
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
