variables {
  aws_region_primary   = "us-west-2"
  aws_region_secondary = "us-east-1"
  domain_name         = "example.com"
  environment         = "test"
}

provider "aws" {
  region = var.aws_region_primary
  alias  = "primary"
}

provider "aws" {
  region = var.aws_region_secondary
  alias  = "secondary"
}

run "validate_consul_federation" {
  command = plan

  assert {
    condition     = length(module.consul_federation.aws_route53_zone) > 0
    error_message = "Route53 zone should be created"
  }

  assert {
    condition     = length(module.consul_federation.aws_acm_certificate) > 0
    error_message = "ACM certificate should be created"
  }
}

run "verify_backup_configuration" {
  command = plan

  assert {
    condition     = length(module.consul_federation.aws_s3_bucket) > 0
    error_message = "Backup S3 bucket should be created"
  }

  assert {
    condition     = module.consul_federation.aws_s3_bucket_versioning[0].versioning_configuration[0].status == "Enabled"
    error_message = "S3 bucket versioning should be enabled"
  }
}

run "verify_monitoring_setup" {
  command = plan

  assert {
    condition     = length(module.consul_federation.helm_release) > 0
    error_message = "Monitoring stack should be deployed"
  }
}
