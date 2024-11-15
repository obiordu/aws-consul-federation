output "prometheus_endpoint" {
  description = "Internal endpoint for Prometheus"
  value       = "http://prometheus-server.monitoring.svc.cluster.local:9090"
}

output "alertmanager_endpoint" {
  description = "Internal endpoint for AlertManager"
  value       = "http://alertmanager.monitoring.svc.cluster.local:9093"
}

output "grafana_endpoint" {
  description = "External endpoint for Grafana"
  value       = "https://grafana.${var.domain_name}"
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring stack"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_service_account" {
  description = "Service account used by Prometheus"
  value       = kubernetes_service_account.prometheus.metadata[0].name
}

output "prometheus_storage_class" {
  description = "Storage class used by Prometheus"
  value       = var.prometheus_storage_class
}

output "alertmanager_config_secret" {
  description = "Name of the AlertManager configuration secret"
  value       = kubernetes_secret.alertmanager_config.metadata[0].name
}
