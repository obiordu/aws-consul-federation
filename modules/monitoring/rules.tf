resource "kubernetes_config_map" "prometheus_rules" {
  for_each = local.regions
  provider = kubernetes.${each.key}

  metadata {
    name      = "prometheus-consul-rules"
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "prometheus"
      "app.kubernetes.io/part-of" = "kube-prometheus-stack"
      "role"                      = "alert-rules"
    }
  }

  data = {
    "consul_rules.yaml"      = file("${path.module}/rules/consul_rules.yaml")
    "service_mesh_rules.yaml" = file("${path.module}/rules/service_mesh_rules.yaml")
  }
}

resource "kubernetes_config_map" "grafana_dashboards" {
  for_each = local.regions
  provider = kubernetes.${each.key}

  metadata {
    name      = "grafana-consul-dashboards"
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
    labels = {
      "grafana_dashboard" = "1"
    }
  }

  data = {
    "consul-federation.json"    = file("${path.module}/dashboards/consul-federation.json")
    "service-mesh-traffic.json" = file("${path.module}/dashboards/service-mesh-traffic.json")
  }
}

resource "kubernetes_secret" "alertmanager_config" {
  for_each = local.regions
  provider = kubernetes.${each.key}

  metadata {
    name      = "alertmanager-config"
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
  }

  data = {
    "alertmanager.yaml" = templatefile("${path.module}/alertmanager/alertmanager.yml", {
      slack_webhook_url      = var.slack_webhook_url
      pagerduty_routing_key  = var.pagerduty_routing_key
      grafana_url           = "https://grafana.${var.domain_name}"
    })
  }

  type = "Opaque"
}
