variable "domain_name" {
  description = "Domain name for Consul UI ingress"
  type        = string
}

variable "admin_email" {
  description = "Email address for Let's Encrypt certificate"
  type        = string
}

variable "regions" {
  description = "Map of AWS regions and their configurations"
  type = map(object({
    region_name = string
    vpc_id      = string
    subnet_ids  = list(string)
  }))
  default = {
    us-west-2 = {
      region_name = "us-west-2"
      vpc_id      = ""
      subnet_ids  = []
    }
    us-east-1 = {
      region_name = "us-east-1"
      vpc_id      = ""
      subnet_ids  = []
    }
  }
}

variable "eks_cluster_names" {
  description = "Map of region to EKS cluster names"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
