# Primary health check for us-west-2
resource "aws_route53_health_check" "primary" {
  provider = aws.us-west-2

  fqdn              = "consul-ui.${var.domain_name}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/v1/status/leader"
  failure_threshold = "2"
  request_interval  = "10"
  regions          = ["us-west-1", "us-west-2", "us-east-1"]
  measure_latency  = true
  
  tags = merge(var.tags, {
    Name = "consul-primary-health-check"
    Environment = "production"
  })
}

# Secondary health check for us-east-1
resource "aws_route53_health_check" "secondary" {
  provider = aws.us-east-1

  fqdn              = "consul-ui-east.${var.domain_name}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/v1/status/leader"
  failure_threshold = "2"
  request_interval  = "10"
  regions          = ["us-east-1", "us-east-2", "us-west-2"]
  measure_latency  = true

  tags = merge(var.tags, {
    Name = "consul-secondary-health-check"
    Environment = "production"
  })
}

# Calculated health check combining multiple endpoints
resource "aws_route53_health_check" "primary_calculated" {
  provider = aws.us-west-2

  type                            = "CALCULATED"
  child_health_threshold         = 2
  child_healthchecks            = [
    aws_route53_health_check.primary.id,
    aws_route53_health_check.primary_api.id,
    aws_route53_health_check.primary_mesh.id
  ]

  tags = merge(var.tags, {
    Name = "consul-primary-calculated-health"
  })
}

# API endpoint health check
resource "aws_route53_health_check" "primary_api" {
  provider = aws.us-west-2

  fqdn              = "consul-ui.${var.domain_name}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/v1/agent/members"
  failure_threshold = "2"
  request_interval  = "10"
  regions          = ["us-west-1", "us-west-2", "us-east-1"]

  tags = merge(var.tags, {
    Name = "consul-primary-api-health"
  })
}

# Mesh Gateway health check
resource "aws_route53_health_check" "primary_mesh" {
  provider = aws.us-west-2

  port              = 443
  type              = "TCP"
  ip_address        = data.aws_lb.consul_mesh_primary.dns_name
  failure_threshold = "2"
  request_interval  = "10"
  regions          = ["us-west-1", "us-west-2", "us-east-1"]

  tags = merge(var.tags, {
    Name = "consul-primary-mesh-health"
  })
}

# Primary record with latency-based routing
resource "aws_route53_record" "primary" {
  provider = aws.us-west-2
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = "consul.${var.domain_name}"
  type     = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = data.aws_lb.consul_primary.dns_name
    zone_id               = data.aws_lb.consul_primary.zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.primary_calculated.id
  set_identifier  = "primary"

  latency_routing_policy {
    region = "us-west-2"
  }
}

# Secondary record with latency-based routing
resource "aws_route53_record" "secondary" {
  provider = aws.us-east-1
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = "consul.${var.domain_name}"
  type     = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = data.aws_lb.consul_secondary.dns_name
    zone_id               = data.aws_lb.consul_secondary.zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.secondary.id
  set_identifier  = "secondary"

  latency_routing_policy {
    region = "us-east-1"
  }
}

# Region-specific records (always active)
resource "aws_route53_record" "primary_region" {
  provider = aws.us-west-2
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = "consul-ui.${var.domain_name}"
  type     = "A"

  alias {
    name                   = data.aws_lb.consul_primary.dns_name
    zone_id               = data.aws_lb.consul_primary.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "secondary_region" {
  provider = aws.us-east-1
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = "consul-ui-east.${var.domain_name}"
  type     = "A"

  alias {
    name                   = data.aws_lb.consul_secondary.dns_name
    zone_id               = data.aws_lb.consul_secondary.zone_id
    evaluate_target_health = true
  }
}

# CloudWatch alarms for health checks
resource "aws_cloudwatch_metric_alarm" "primary_health" {
  provider = aws.us-west-2

  alarm_name          = "consul-primary-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "HealthCheckStatus"
  namespace          = "AWS/Route53"
  period             = "60"
  statistic          = "Minimum"
  threshold          = "1"
  alarm_description  = "This metric monitors primary Consul cluster health"
  alarm_actions      = [aws_sns_topic.consul_alerts.arn]
  ok_actions         = [aws_sns_topic.consul_alerts.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary_calculated.id
  }
}

# SNS topic for health alerts
resource "aws_sns_topic" "consul_alerts" {
  provider = aws.us-west-2
  name     = "consul-health-alerts"

  tags = merge(var.tags, {
    Name = "consul-health-alerts"
  })
}

# Route53 DNS query logging
resource "aws_route53_query_log" "main" {
  provider = aws.us-west-2

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.dns_logs.arn
  zone_id                  = data.aws_route53_zone.main.zone_id
}

# CloudWatch log group for DNS logs
resource "aws_cloudwatch_log_group" "dns_logs" {
  provider = aws.us-west-2
  name     = "/aws/route53/${var.domain_name}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "consul-dns-logs"
  })
}

# Data sources for ALBs
data "aws_lb" "consul_primary" {
  provider = aws.us-west-2
  tags = {
    "ingress.k8s.aws/stack" = "consul"
  }
  depends_on = [kubernetes_manifest.ingress_config_primary]
}

data "aws_lb" "consul_secondary" {
  provider = aws.us-east-1
  tags = {
    "ingress.k8s.aws/stack" = "consul"
  }
  depends_on = [kubernetes_manifest.ingress_config_secondary]
}

data "aws_lb" "consul_mesh_primary" {
  provider = aws.us-west-2
  tags = {
    "ingress.k8s.aws/stack" = "consul-mesh"
  }
  depends_on = [kubernetes_manifest.ingress_config_mesh_primary]
}

# Route53 zone data source
data "aws_route53_zone" "main" {
  provider = aws.us-west-2
  name     = var.domain_name
}
