# Route53 Health Checks
resource "aws_route53_health_check" "primary" {
  provider = aws.primary

  fqdn              = module.eks["primary"].cluster_endpoint
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name = "primary-consul-health-check"
  }
}

resource "aws_route53_health_check" "secondary" {
  provider = aws.secondary

  fqdn              = module.eks["secondary"].cluster_endpoint
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name = "secondary-consul-health-check"
  }
}

# Route53 Hosted Zone
resource "aws_route53_zone" "consul" {
  provider = aws.primary
  name     = var.domain_name

  tags = {
    Environment = var.environment
  }
}

# Primary Record
resource "aws_route53_record" "primary" {
  provider = aws.primary
  zone_id  = aws_route53_zone.consul.zone_id
  name     = "consul.${var.domain_name}"
  type     = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = module.eks["primary"].cluster_endpoint
    zone_id                = module.eks["primary"].cluster_zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.primary.id
  set_identifier  = "primary"
}

# Secondary Record
resource "aws_route53_record" "secondary" {
  provider = aws.secondary
  zone_id  = aws_route53_zone.consul.zone_id
  name     = "consul.${var.domain_name}"
  type     = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = module.eks["secondary"].cluster_endpoint
    zone_id                = module.eks["secondary"].cluster_zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.secondary.id
  set_identifier  = "secondary"
}

# Regional Records
resource "aws_route53_record" "regional" {
  for_each = local.regions
  
  provider = aws[each.key]
  zone_id  = aws_route53_zone.consul.zone_id
  name     = "${each.key}.consul.${var.domain_name}"
  type     = "A"

  alias {
    name                   = module.eks[each.key].cluster_endpoint
    zone_id                = module.eks[each.key].cluster_zone_id
    evaluate_target_health = true
  }
}

# Service Discovery Records
resource "aws_service_discovery_private_dns_namespace" "consul" {
  for_each = local.regions
  
  provider = aws[each.key]
  name     = "${each.key}.consul.local"
  vpc      = module.networking[each.key].vpc_id
}

# Monitoring Endpoints
resource "aws_route53_record" "monitoring" {
  provider = aws.primary
  zone_id  = aws_route53_zone.consul.zone_id
  name     = "monitoring.${var.domain_name}"
  type     = "A"

  alias {
    name                   = module.monitoring.endpoint
    zone_id                = module.monitoring.zone_id
    evaluate_target_health = true
  }
}
