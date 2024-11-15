variables {
  aws_region     = "us-west-2"
  cluster_name   = "test-eks"
  instance_types = ["t3.medium"]
  desired_size   = 2
  max_size       = 3
  min_size       = 1
}

provider "aws" {
  region = var.aws_region
}

run "validate_eks_cluster" {
  command = plan

  assert {
    condition     = length(aws_eks_cluster.cluster) > 0
    error_message = "EKS cluster should be created"
  }

  assert {
    condition     = length(aws_eks_node_group.nodes) > 0
    error_message = "EKS node group should be created"
  }
}

run "verify_node_group_config" {
  command = plan

  assert {
    condition     = aws_eks_node_group.nodes[0].scaling_config[0].desired_size == var.desired_size
    error_message = "Node group desired size does not match input"
  }

  assert {
    condition     = aws_eks_node_group.nodes[0].scaling_config[0].max_size == var.max_size
    error_message = "Node group max size does not match input"
  }

  assert {
    condition     = aws_eks_node_group.nodes[0].scaling_config[0].min_size == var.min_size
    error_message = "Node group min size does not match input"
  }
}
