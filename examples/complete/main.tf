provider "aws" {
  region = "us-west-2"  # Primary region
}

module "consul_federation" {
  source = "../../"

  environment = "dev"
  regions = {
    primary   = "us-west-2"
    secondary = "us-east-1"
  }
  domain_name = "consul.example.com"

  # Optional: Override defaults
  primary_vpc_cidr   = "10.0.0.0/16"
  secondary_vpc_cidr = "10.1.0.0/16"
  consul_version     = "1.16.0"
}
