locals {
  aws_lb_controller_version = "2.6.0"
}

resource "helm_release" "aws_lb_controller_primary" {
  provider = helm.us-west-2

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = local.aws_lb_controller_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.eks_cluster_names["us-west-2"]
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_lb_controller["us-west-2"].arn
  }

  depends_on = [aws_iam_role_policy_attachment.aws_lb_controller["us-west-2"]]
}

resource "helm_release" "aws_lb_controller_secondary" {
  provider = helm.us-east-1

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = local.aws_lb_controller_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.eks_cluster_names["us-east-1"]
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_lb_controller["us-east-1"].arn
  }

  depends_on = [aws_iam_role_policy_attachment.aws_lb_controller["us-east-1"]]
}

# IAM role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_lb_controller" {
  for_each = var.regions

  name = "eks-aws-lb-controller-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.us-west-2.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.us-west-2.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for AWS Load Balancer Controller
resource "aws_iam_role_policy" "aws_lb_controller" {
  for_each = var.regions

  name = "eks-aws-lb-controller-${each.key}"
  role = aws_iam_role.aws_lb_controller[each.key].id

  policy = file("${path.module}/policies/aws-lb-controller-policy.json")
}

# Attach AWS managed policy for ALB controller
resource "aws_iam_role_policy_attachment" "aws_lb_controller" {
  for_each = var.regions

  policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy"
  role       = aws_iam_role.aws_lb_controller[each.key].name
}
