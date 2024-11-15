terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = ">= 2.17.0"
    }
  }
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

data "aws_eks_cluster" "us-west-2" {
  provider = aws.us-west-2
  name     = var.eks_cluster_names["us-west-2"]
}

data "aws_eks_cluster_auth" "us-west-2" {
  provider = aws.us-west-2
  name     = var.eks_cluster_names["us-west-2"]
}

data "aws_eks_cluster" "us-east-1" {
  provider = aws.us-east-1
  name     = var.eks_cluster_names["us-east-1"]
}

data "aws_eks_cluster_auth" "us-east-1" {
  provider = aws.us-east-1
  name     = var.eks_cluster_names["us-east-1"]
}

provider "kubernetes" {
  alias                  = "us-west-2"
  host                   = data.aws_eks_cluster.us-west-2.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.us-west-2.certificate_authority[0].data)
  token                 = data.aws_eks_cluster_auth.us-west-2.token
}

provider "kubernetes" {
  alias                  = "us-east-1"
  host                   = data.aws_eks_cluster.us-east-1.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.us-east-1.certificate_authority[0].data)
  token                 = data.aws_eks_cluster_auth.us-east-1.token
}

provider "helm" {
  alias = "us-west-2"
  kubernetes {
    host                   = data.aws_eks_cluster.us-west-2.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.us-west-2.certificate_authority[0].data)
    token                 = data.aws_eks_cluster_auth.us-west-2.token
  }
}

provider "helm" {
  alias = "us-east-1"
  kubernetes {
    host                   = data.aws_eks_cluster.us-east-1.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.us-east-1.certificate_authority[0].data)
    token                 = data.aws_eks_cluster_auth.us-east-1.token
  }
}

provider "consul" {
  alias = "primary"
  address = "https://consul-ui.${var.domain_name}"
  token   = data.kubernetes_secret.consul_bootstrap_token.data["token"]
}

provider "consul" {
  alias = "secondary"
  address = "https://consul-ui-east.${var.domain_name}"
  token   = data.kubernetes_secret.consul_replication_token.data["token"]
}
