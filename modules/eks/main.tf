locals {
  regions = {
    primary   = "us-west-2"
    secondary = "us-east-1"
  }
}

# EKS Cluster Role
resource "aws_iam_role" "eks_cluster" {
  for_each = local.regions

  provider = aws.${each.key}
  name     = "consul-eks-cluster-role-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  for_each = local.regions

  provider   = aws.${each.key}
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster[each.key].name
}

# EKS Node Role
resource "aws_iam_role" "eks_node" {
  for_each = local.regions

  provider = aws.${each.key}
  name     = "consul-eks-node-role-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  for_each = local.regions

  provider   = aws.${each.key}
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node[each.key].name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  for_each = local.regions

  provider   = aws.${each.key}
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node[each.key].name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  for_each = local.regions

  provider   = aws.${each.key}
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node[each.key].name
}

# EKS Cluster
resource "aws_eks_cluster" "cluster" {
  for_each = local.regions

  provider = aws.${each.key}
  name     = "consul-cluster-${each.key}"
  role_arn = aws_iam_role.eks_cluster[each.key].arn
  version  = "1.27"

  vpc_config {
    subnet_ids              = var.private_subnet_ids[each.key]
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster[each.key].id]
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn[each.key]
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# EKS Node Groups
resource "aws_eks_node_group" "consul" {
  for_each = local.regions

  provider        = aws.${each.key}
  cluster_name    = aws_eks_cluster.cluster[each.key].name
  node_group_name = "consul-nodes-${each.key}"
  node_role_arn   = aws_iam_role.eks_node[each.key].arn
  subnet_ids      = var.private_subnet_ids[each.key]

  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 3
  }

  instance_types = ["t3.large"]

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "consul"
  }

  tags = {
    Environment = "production"
    Terraform   = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry,
  ]
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster" {
  for_each = local.regions

  provider    = aws.${each.key}
  name        = "consul-eks-cluster-sg-${each.key}"
  description = "Security group for Consul EKS cluster"
  vpc_id      = var.vpc_id[each.key]

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [
      var.vpc_cidr[each.key],
      each.key == "primary" ? var.vpc_cidr["secondary"] : var.vpc_cidr["primary"]
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "consul-eks-cluster-sg-${each.key}"
  }
}
