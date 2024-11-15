# Main Consul Federation Module

locals {
  regions = {
    primary   = var.regions.primary
    secondary = var.regions.secondary
  }
}

# EKS Clusters
module "eks" {
  for_each = local.regions
  source   = "../eks"

  region            = each.value
  environment       = var.environment
  cluster_name      = "consul-${var.environment}-${each.key}"
  vpc_id            = module.networking[each.key].vpc_id
  private_subnets   = module.networking[each.key].private_subnets
  
  node_groups = {
    consul = {
      desired_size = 3
      min_size     = 3
      max_size     = 5
      instance_types = ["t3.large"]
    }
  }
}

# Networking
module "networking" {
  for_each = local.regions
  source   = "../networking"

  region      = each.value
  environment = var.environment
  cidr_block  = each.key == "primary" ? var.primary_vpc_cidr : var.secondary_vpc_cidr
}

# Consul Installation
resource "helm_release" "consul" {
  for_each = local.regions
  
  name       = "consul"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"
  version    = var.consul_version
  namespace  = "consul"

  values = [
    templatefile("${path.module}/templates/consul-values.yaml", {
      datacenter     = each.key
      is_primary     = each.key == "primary"
      domain         = var.domain_name
      replicas      = 3
      federation_enabled = true
      primary_datacenter = "primary"
      mesh_gateway_enabled = true
      tls_enabled    = true
      acls_enabled   = true
    })
  ]

  depends_on = [module.eks]
}

# Federation Setup
resource "consul_config_entry" "mesh" {
  provider = consul.primary
  name     = "mesh"
  kind     = "mesh"

  config_json = jsonencode({
    peering = {
      enabled = true
    }
    federation = {
      enabled = true
    }
  })

  depends_on = [helm_release.consul]
}

# Backup Configuration
resource "aws_s3_bucket" "backup" {
  provider = aws.primary
  bucket   = "consul-backup-${var.environment}"
  
  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Monitoring
resource "helm_release" "prometheus" {
  for_each = local.regions
  
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = "monitoring"

  set {
    name  = "server.global.external_labels.datacenter"
    value = each.key
  }
}
