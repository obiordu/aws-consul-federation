locals {
  regions = {
    primary   = "us-west-2"
    secondary = "us-east-1"
  }
}

# Consul Namespace
resource "kubernetes_namespace" "consul" {
  for_each = local.regions

  provider = kubernetes.${each.key}

  metadata {
    name = "consul"
    
    labels = {
      name = "consul"
    }
  }
}

# Fetch secrets from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "ca_cert" {
  for_each = local.regions
  provider = aws.${each.key}
  secret_id = var.consul_ca_secret_id[each.key]
}

data "aws_secretsmanager_secret_version" "server_cert" {
  for_each = local.regions
  provider = aws.${each.key}
  secret_id = var.consul_server_secret_id[each.key]
}

data "aws_secretsmanager_secret_version" "gossip_key" {
  for_each = local.regions
  provider = aws.${each.key}
  secret_id = var.consul_gossip_key_id[each.key]
}

# Create Kubernetes secrets for Consul
resource "kubernetes_secret" "consul_certs" {
  for_each = local.regions

  provider = kubernetes.${each.key}

  metadata {
    name      = "consul-certs"
    namespace = kubernetes_namespace.consul[each.key].metadata[0].name
  }

  data = {
    "ca.pem"     = jsondecode(data.aws_secretsmanager_secret_version.ca_cert[each.key].secret_string)["cert"]
    "server.pem" = jsondecode(data.aws_secretsmanager_secret_version.server_cert[each.key].secret_string)["cert"]
    "server-key.pem" = jsondecode(data.aws_secretsmanager_secret_version.server_cert[each.key].secret_string)["key"]
  }
}

resource "kubernetes_secret" "consul_gossip" {
  for_each = local.regions

  provider = kubernetes.${each.key}

  metadata {
    name      = "consul-gossip"
    namespace = kubernetes_namespace.consul[each.key].metadata[0].name
  }

  data = {
    "gossip.key" = data.aws_secretsmanager_secret_version.gossip_key[each.key].secret_string
  }
}

# Deploy Consul using Helm
resource "helm_release" "consul_primary" {
  provider = helm.us-west-2

  name             = "consul"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "consul"
  version          = "1.2.0"
  namespace        = "consul"
  create_namespace = true

  values = [
    templatefile("${path.module}/values/consul-primary.yaml", {
      eks_cluster_endpoint        = data.aws_eks_cluster.us-west-2.endpoint
      domain_name                = var.domain_name
      consul_ca_secret           = kubernetes_secret.consul_ca.metadata[0].name
      consul_gossip_secret       = kubernetes_secret.consul_gossip.metadata[0].name
      consul_bootstrap_token_secret = kubernetes_secret.consul_bootstrap_token.metadata[0].name
    })
  ]

  depends_on = [
    kubernetes_secret.consul_ca,
    kubernetes_secret.consul_gossip,
    kubernetes_secret.consul_bootstrap_token
  ]
}

resource "helm_release" "consul_secondary" {
  provider = helm.us-east-1

  name             = "consul"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "consul"
  version          = "1.2.0"
  namespace        = "consul"
  create_namespace = true

  values = [
    templatefile("${path.module}/values/consul-secondary.yaml", {
      eks_cluster_endpoint        = data.aws_eks_cluster.us-east-1.endpoint
      domain_name                = var.domain_name
      consul_ca_secret           = kubernetes_secret.consul_ca.metadata[0].name
      consul_gossip_secret       = kubernetes_secret.consul_gossip.metadata[0].name
      consul_replication_token_secret = kubernetes_secret.consul_replication_token.metadata[0].name
    })
  ]

  depends_on = [
    helm_release.consul_primary,
    kubernetes_secret.consul_ca,
    kubernetes_secret.consul_gossip,
    kubernetes_secret.consul_replication_token
  ]
}

resource "kubernetes_manifest" "ingress_config_primary" {
  provider = kubernetes.us-west-2
  for_each = fileset("${path.module}/manifests", "*.yaml")

  manifest = yamldecode(templatefile("${path.module}/manifests/${each.value}", {
    admin_email = var.admin_email
  }))

  depends_on = [helm_release.consul_primary]
}

resource "kubernetes_manifest" "ingress_config_secondary" {
  provider = kubernetes.us-east-1
  for_each = fileset("${path.module}/manifests", "*.yaml")

  manifest = yamldecode(templatefile("${path.module}/manifests/${each.value}", {
    admin_email = var.admin_email
  }))

  depends_on = [helm_release.consul_secondary]
}

# Create federation secret in secondary datacenter
resource "kubernetes_secret" "consul_federation" {
  provider = kubernetes.us-east-1

  metadata {
    name      = "consul-federation"
    namespace = "consul"
  }

  data = {
    serverConfigJSON = jsonencode({
      primary_datacenter = "us-west-2"
      primary_gateways = [
        {
          address = data.kubernetes_service.mesh_gateway_primary.status[0].load_balancer[0].ingress[0].hostname
          port    = 443
        }
      ]
    })
  }

  depends_on = [helm_release.consul_primary]
}

# Get the mesh gateway service from primary datacenter
data "kubernetes_service" "mesh_gateway_primary" {
  provider = kubernetes.us-west-2

  metadata {
    name      = "consul-mesh-gateway"
    namespace = "consul"
  }

  depends_on = [helm_release.consul_primary]
}

# Configure federation between datacenters
resource "consul_config_entry" "proxy_defaults" {
  for_each = local.regions

  provider = consul.${each.key}
  kind     = "proxy-defaults"
  name     = "global"

  config_json = jsonencode({
    Config = {
      protocol = "http"
    }
  })

  depends_on = [helm_release.consul_primary, helm_release.consul_secondary]
}

resource "consul_config_entry" "mesh" {
  provider = consul.primary
  kind     = "mesh"
  name     = "mesh"

  config_json = jsonencode({
    TransparentProxy = {
      MeshDestinationsOnly = true
    }
  })

  depends_on = [helm_release.consul_primary, helm_release.consul_secondary]
}

# Configure Consul backups
resource "kubernetes_cron_job" "consul_backup" {
  for_each = local.regions

  provider = kubernetes.${each.key}

  metadata {
    name      = "consul-backup"
    namespace = kubernetes_namespace.consul[each.key].metadata[0].name
  }

  spec {
    schedule = "0 */6 * * *"  # Every 6 hours
    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            container {
              name    = "consul-backup"
              image   = "hashicorp/consul:1.16"
              command = ["/bin/sh", "-c"]
              args    = [
                "consul snapshot save /backup/consul-$(date +%Y%m%d-%H%M%S).snap && aws s3 cp /backup/*.snap s3://${var.backup_bucket}/$(date +%Y/%m/%d)/"
              ]

              volume_mount {
                name       = "backup"
                mount_path = "/backup"
              }

              env {
                name  = "AWS_REGION"
                value = each.value
              }
            }

            volume {
              name = "backup"
              empty_dir {}
            }

            service_account_name = "consul-backup"
          }
        }
      }
    }
  }
}

# Create service account for backups
resource "kubernetes_service_account" "consul_backup" {
  for_each = local.regions

  provider = kubernetes.${each.key}

  metadata {
    name      = "consul-backup"
    namespace = kubernetes_namespace.consul[each.key].metadata[0].name
  }
}

# IAM role for backup service account
resource "aws_iam_role" "consul_backup" {
  for_each = local.regions

  provider = aws.${each.key}
  name     = "consul-backup-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.eks_oidc_provider_arn[each.key]
        }
        Condition = {
          StringEquals = {
            "${var.eks_oidc_provider[each.key]}:sub": "system:serviceaccount:consul:consul-backup"
          }
        }
      }
    ]
  })
}

# IAM policy for S3 backup access
resource "aws_iam_role_policy" "consul_backup" {
  for_each = local.regions

  provider = aws.${each.key}
  name     = "consul-backup-${each.key}"
  role     = aws_iam_role.consul_backup[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.backup_bucket}",
          "arn:aws:s3:::${var.backup_bucket}/*"
        ]
      }
    ]
  })
}
