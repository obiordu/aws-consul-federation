provider "aws" {
  alias  = "primary"
  region = var.regions.primary
}

provider "aws" {
  alias  = "secondary"
  region = var.regions.secondary
}

provider "kubernetes" {
  alias = "primary"
  # Configuration will be populated by aws eks update-kubeconfig
}

provider "kubernetes" {
  alias = "secondary"
  # Configuration will be populated by aws eks update-kubeconfig
}

provider "helm" {
  alias = "primary"
  kubernetes {
    config_path = module.consul_federation.primary_kubeconfig
  }
}

provider "helm" {
  alias = "secondary"
  kubernetes {
    config_path = module.consul_federation.secondary_kubeconfig
  }
}

module "consul_federation" {
  source = "./modules/consul-federation"

  environment = var.environment
  regions     = var.regions
  domain_name = var.domain_name

  primary_vpc_cidr   = var.primary_vpc_cidr
  secondary_vpc_cidr = var.secondary_vpc_cidr

  consul_version = var.consul_version

  providers = {
    aws.primary    = aws.primary
    aws.secondary  = aws.secondary
    helm.primary   = helm.primary
    helm.secondary = helm.secondary
  }
}
