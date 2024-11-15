resource "kubernetes_service_account" "prometheus" {
  for_each = local.regions
  provider = kubernetes.${each.key}

  metadata {
    name      = "prometheus-server"
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
  }
}

resource "kubernetes_cluster_role" "prometheus" {
  for_each = local.regions
  provider = kubernetes.${each.key}

  metadata {
    name = "prometheus-server"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "nodes/metrics", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  for_each = local.regions
  provider = kubernetes.${each.key}

  metadata {
    name = "prometheus-server"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus[each.key].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.prometheus[each.key].metadata[0].name
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
  }
}

# Additional role for Consul service discovery
resource "kubernetes_role" "prometheus_consul" {
  for_each = local.regions
  provider = kubernetes.${each.key}

  metadata {
    name      = "prometheus-consul"
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "prometheus_consul" {
  for_each = local.regions
  provider = kubernetes.${each.key}

  metadata {
    name      = "prometheus-consul"
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.prometheus_consul[each.key].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.prometheus[each.key].metadata[0].name
    namespace = kubernetes_namespace.monitoring[each.key].metadata[0].name
  }
}
