locals {
  regions = {
    primary   = "us-west-2"
    secondary = "us-east-1"
  }
}

# KMS key for EKS encryption
resource "aws_kms_key" "eks" {
  for_each = local.regions

  provider = aws.${each.key}

  description             = "KMS key for EKS cluster encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "consul-eks-kms-${each.key}"
  }
}

resource "aws_kms_alias" "eks" {
  for_each = local.regions

  provider = aws.${each.key}

  name          = "alias/consul-eks-${each.key}"
  target_key_id = aws_kms_key.eks[each.key].key_id
}

# KMS key for Consul encryption
resource "aws_kms_key" "consul" {
  for_each = local.regions

  provider = aws.${each.key}

  description             = "KMS key for Consul encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "consul-kms-${each.key}"
  }
}

resource "aws_kms_alias" "consul" {
  for_each = local.regions

  provider = aws.${each.key}

  name          = "alias/consul-${each.key}"
  target_key_id = aws_kms_key.consul[each.key].key_id
}

# TLS certificates for Consul
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "Consul CA"
    organization = "HashiCorp"
  }

  validity_period_hours = 87600
  is_ca_certificate    = true

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature"
  ]
}

resource "tls_private_key" "server" {
  for_each = local.regions

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "server" {
  for_each = local.regions

  private_key_pem = tls_private_key.server[each.key].private_key_pem

  subject {
    common_name  = "server.${each.key}.consul"
    organization = "HashiCorp"
  }

  dns_names = [
    "server.${each.key}.consul",
    "localhost"
  ]

  ip_addresses = ["127.0.0.1"]
}

resource "tls_locally_signed_cert" "server" {
  for_each = local.regions

  cert_request_pem   = tls_cert_request.server[each.key].cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 87600

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

# Store certificates in AWS Secrets Manager
resource "aws_secretsmanager_secret" "consul_ca" {
  for_each = local.regions

  provider = aws.${each.key}

  name        = "consul-ca-cert-${each.key}"
  description = "Consul CA certificate"
  kms_key_id  = aws_kms_key.consul[each.key].arn
}

resource "aws_secretsmanager_secret_version" "consul_ca" {
  for_each = local.regions

  provider = aws.${each.key}

  secret_id = aws_secretsmanager_secret.consul_ca[each.key].id
  secret_string = jsonencode({
    cert = tls_self_signed_cert.ca.cert_pem
    key  = tls_private_key.ca.private_key_pem
  })
}

resource "aws_secretsmanager_secret" "consul_server" {
  for_each = local.regions

  provider = aws.${each.key}

  name        = "consul-server-cert-${each.key}"
  description = "Consul server certificate"
  kms_key_id  = aws_kms_key.consul[each.key].arn
}

resource "aws_secretsmanager_secret_version" "consul_server" {
  for_each = local.regions

  provider = aws.${each.key}

  secret_id = aws_secretsmanager_secret.consul_server[each.key].id
  secret_string = jsonencode({
    cert = tls_locally_signed_cert.server[each.key].cert_pem
    key  = tls_private_key.server[each.key].private_key_pem
  })
}

# Generate Consul gossip encryption key
resource "random_id" "gossip_encryption_key" {
  byte_length = 32
}

resource "aws_secretsmanager_secret" "gossip_key" {
  for_each = local.regions

  provider = aws.${each.key}

  name        = "consul-gossip-key-${each.key}"
  description = "Consul gossip encryption key"
  kms_key_id  = aws_kms_key.consul[each.key].arn
}

resource "aws_secretsmanager_secret_version" "gossip_key" {
  for_each = local.regions

  provider = aws.${each.key}

  secret_id     = aws_secretsmanager_secret.gossip_key[each.key].id
  secret_string = base64encode(random_id.gossip_encryption_key.hex)
}
