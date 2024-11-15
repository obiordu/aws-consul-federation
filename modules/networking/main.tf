locals {
  regions = {
    primary   = "us-west-2"
    secondary = "us-east-1"
  }
}

# VPC for each region
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  for_each = local.regions

  name = "consul-vpc-${each.key}"
  cidr = each.key == "primary" ? "10.0.0.0/16" : "10.1.0.0/16"

  azs             = [for i in ["a", "b", "c"] : "${each.value}${i}"]
  private_subnets = each.key == "primary" ? ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] : ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets  = each.key == "primary" ? ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"] : ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  enable_vpn_gateway     = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS
  private_subnet_tags = {
    "kubernetes.io/cluster/consul-cluster-${each.key}" = "shared"
    "kubernetes.io/role/internal-elb"                  = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/consul-cluster-${each.key}" = "shared"
    "kubernetes.io/role/elb"                           = "1"
  }

  tags = {
    Environment = "production"
    Terraform   = "true"
    Region      = each.value
  }
}

# Transit Gateway for cross-region communication
resource "aws_ec2_transit_gateway" "tgw" {
  for_each = local.regions

  provider = aws.${each.key}

  description = "Transit Gateway for Consul Federation - ${each.key}"
  
  tags = {
    Name = "consul-tgw-${each.key}"
  }
}

# Transit Gateway VPC attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attachment" {
  for_each = local.regions

  provider = aws.${each.key}

  subnet_ids         = module.vpc[each.key].private_subnets
  transit_gateway_id = aws_ec2_transit_gateway.tgw[each.key].id
  vpc_id            = module.vpc[each.key].vpc_id

  tags = {
    Name = "consul-tgw-attachment-${each.key}"
  }
}

# Transit Gateway Peering
resource "aws_ec2_transit_gateway_peering_attachment" "tgw_peering" {
  provider = aws.primary

  peer_account_id         = data.aws_caller_identity.current.account_id
  peer_region            = local.regions.secondary
  peer_transit_gateway_id = aws_ec2_transit_gateway.tgw["secondary"].id
  transit_gateway_id      = aws_ec2_transit_gateway.tgw["primary"].id

  tags = {
    Name = "consul-tgw-peering"
  }
}

# Accept the peering attachment in the secondary region
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "tgw_peering_accept" {
  provider = aws.secondary

  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.tgw_peering.id

  tags = {
    Name = "consul-tgw-peering-accepter"
  }
}

# Route tables for cross-region communication
resource "aws_ec2_transit_gateway_route_table" "tgw_rt" {
  for_each = local.regions

  provider = aws.${each.key}

  transit_gateway_id = aws_ec2_transit_gateway.tgw[each.key].id

  tags = {
    Name = "consul-tgw-rt-${each.key}"
  }
}

# VPC route tables
resource "aws_route_table" "private" {
  for_each = local.regions

  provider = aws.${each.key}
  vpc_id   = module.vpc[each.key].vpc_id

  route {
    cidr_block         = each.key == "primary" ? "10.1.0.0/16" : "10.0.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.tgw[each.key].id
  }

  tags = {
    Name = "consul-private-rt-${each.key}"
  }
}
