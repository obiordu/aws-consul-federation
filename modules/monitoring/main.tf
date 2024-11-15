locals {
  regions = {
    primary   = "us-west-2"
    secondary = "us-east-1"
  }
}

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  for_each = local.regions

  provider = kubernetes.${each.key}

  metadata {
    name = "monitoring"
    
    labels = {
      name = "monitoring"
    }
  }
}

# Deploy Prometheus using Helm
resource "helm_release" "prometheus" {
  for_each = local.regions

  provider = helm.${each.key}

  name       = "prometheus"
  namespace  = kubernetes_namespace.monitoring[each.key].metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "45.7.1"

  values = [
    templatefile("${path.module}/prometheus-values.yaml", {
      region = each.value
    })
  ]
}

# Create Grafana dashboards ConfigMap
resource "kubernetes_config_map" "grafana_dashboards" {
  for_each = local.regions

  provider = kubernetes.${each.key}

  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
    
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "consul-federation.json" = file("${path.module}/../../monitoring/consul-dashboard.json")
    "prometheus-rules.yml"   = file("${path.module}/../../monitoring/prometheus-rules.yml")
  }
}

# Deploy Grafana using Helm
resource "helm_release" "grafana" {
  for_each = local.regions

  provider = helm.${each.key}

  name       = "grafana"
  namespace  = kubernetes_namespace.monitoring[each.key].metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "6.50.7"

  values = [
    templatefile("${path.module}/grafana-values.yaml", {
      consul_dashboard = file("${path.module}/../../monitoring/consul-dashboard.json")
      admin_password  = var.grafana_admin_password
      domain_name     = var.domain_name
    })
  ]

  depends_on = [
    helm_release.prometheus
  ]
}

# Create AlertManager configuration
resource "kubernetes_secret" "alertmanager_config" {
  for_each = local.regions

  provider = kubernetes.${each.key}

  metadata {
    name      = "alertmanager-config"
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
  }

  data = {
    "alertmanager.yaml" = templatefile("${path.module}/alertmanager.yaml", {
      slack_api_url = var.slack_webhook_url
      pagerduty_key = var.pagerduty_key
    })
  }
}

# Create recording rules for Consul metrics
resource "kubernetes_config_map" "prometheus_rules" {
  for_each = local.regions

  provider = kubernetes.${each.key}

  metadata {
    name      = "prometheus-consul-rules"
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
    
    labels = {
      "prometheus_rule" = "true"
    }
  }

  data = {
    "consul_rules.yaml" = file("${path.module}/rules/consul_rules.yaml")
  }
}

# Create ServiceMonitor for Consul
resource "kubernetes_manifest" "consul_servicemonitor" {
  for_each = local.regions

  provider = kubernetes.${each.key}

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "consul-metrics"
      namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
      labels = {
        release = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "consul"
        }
      }
      namespaceSelector = {
        matchNames = ["consul"]
      }
      endpoints = [
        {
          port = "http"
          path = "/metrics"
          interval = "30s"
        }
      ]
    }
  }
}
