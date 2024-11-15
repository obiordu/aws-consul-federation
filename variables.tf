variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "regions" {
  description = "AWS regions for primary and secondary datacenters"
  type = object({
    primary   = string
    secondary = string
  })
  default = {
    primary   = "us-west-2"
    secondary = "us-east-1"
  }
}

variable "domain_name" {
  description = "Domain name for Consul UI and service discovery"
  type        = string
}

variable "primary_vpc_cidr" {
  description = "CIDR block for primary VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "secondary_vpc_cidr" {
  description = "CIDR block for secondary VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "consul_version" {
  description = "Version of Consul to install"
  type        = string
  default     = "1.16.0"
}
