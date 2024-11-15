# S3 bucket for Consul backups
resource "aws_s3_bucket" "consul_backup" {
  for_each = var.regions
  provider = aws.${each.key}

  bucket = "consul-backup-${each.key}-${data.aws_caller_identity.current.account_id}"
  
  tags = merge(var.tags, {
    Name = "consul-backup-${each.key}"
    Environment = "production"
  })
}

# Bucket versioning with MFA delete protection
resource "aws_s3_bucket_versioning" "consul_backup" {
  for_each = var.regions
  provider = aws.${each.key}

  bucket = aws_s3_bucket.consul_backup[each.key].id
  versioning_configuration {
    status = "Enabled"
    mfa_delete = "Enabled"
  }
}

# Enhanced bucket encryption with CMK
resource "aws_s3_bucket_server_side_encryption_configuration" "consul_backup" {
  for_each = var.regions
  provider = aws.${each.key}

  bucket = aws_s3_bucket.consul_backup[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.consul_backup[each.key].id
    }
    bucket_key_enabled = true
  }
}

# Cross-region replication configuration
resource "aws_s3_bucket_replication_configuration" "consul_backup" {
  provider = aws.us-west-2
  
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.consul_backup["us-west-2"].id

  rule {
    id     = "ConsulBackupReplication"
    status = "Enabled"

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.consul_backup["us-east-1"].arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.consul_backup["us-east-1"].arn
      }
    }
  }
}

# Enhanced backup CronJob with pre/post hooks
resource "kubernetes_cron_job" "consul_backup" {
  for_each = var.regions
  provider = kubernetes.${each.key}

  metadata {
    name      = "consul-backup"
    namespace = "consul"
  }

  spec {
    schedule = "0 */4 * * *"  # Every 4 hours
    concurrency_policy = "Replace"
    successful_jobs_history_limit = 5
    failed_jobs_history_limit = 3

    job_template {
      metadata {
        name = "consul-backup"
      }

      spec {
        template {
          metadata {
            name = "consul-backup"
          }

          spec {
            service_account_name = "consul-backup"
            init_containers {
              name    = "pre-backup-check"
              image   = "hashicorp/consul:1.16.0"
              command = ["/bin/sh", "-c"]
              args    = [
                <<-EOT
                # Verify Consul health
                consul members || exit 1
                # Check leadership status
                consul operator raft list-peers | grep leader || exit 1
                EOT
              ]

              env {
                name  = "CONSUL_HTTP_ADDR"
                value = "https://consul-server.consul.svc:8501"
              }
              env {
                name  = "CONSUL_HTTP_TOKEN"
                value_from {
                  secret_key_ref {
                    name = "consul-bootstrap-token"
                    key  = "token"
                  }
                }
              }
            }

            containers {
              name    = "consul-backup"
              image   = "hashicorp/consul:1.16.0"
              command = ["/bin/sh", "-c"]
              args    = [
                <<-EOT
                # Take snapshot with timestamp
                BACKUP_FILE="/backup/consul-$(date +%Y%m%d-%H%M%S).snap"
                consul snapshot save $BACKUP_FILE
                
                # Verify backup integrity
                consul snapshot inspect $BACKUP_FILE
                
                # Upload to S3 with metadata
                aws s3 cp $BACKUP_FILE s3://${aws_s3_bucket.consul_backup[each.key].id}/ \
                  --metadata consul_version=$(consul version | head -n1),datacenter=${each.key}
                
                # Clean up old backups (keep last 5)
                ls -t /backup/consul-*.snap | tail -n +6 | xargs rm -f
                EOT
              ]

              env {
                name  = "CONSUL_HTTP_ADDR"
                value = "https://consul-server.consul.svc:8501"
              }
              env {
                name  = "CONSUL_HTTP_TOKEN"
                value_from {
                  secret_key_ref {
                    name = "consul-bootstrap-token"
                    key  = "token"
                  }
                }
              }
              env {
                name  = "AWS_REGION"
                value = each.key
              }

              volume_mount {
                name       = "backup"
                mount_path = "/backup"
              }
            }

            volumes {
              name = "backup"
              empty_dir {
                size_limit = "1Gi"
              }
            }
          }
        }
      }
    }
  }
}

# CloudWatch metrics for backup monitoring
resource "aws_cloudwatch_metric_alarm" "backup_job_failed" {
  for_each = var.regions
  provider = aws.${each.key}

  alarm_name          = "consul-backup-failed-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "BackupJobFailed"
  namespace          = "Consul/Backup"
  period             = "300"
  statistic          = "Sum"
  threshold          = "0"
  alarm_description  = "Consul backup job failed in ${each.key}"
  alarm_actions      = [aws_sns_topic.consul_alerts.arn]

  dimensions = {
    Region = each.key
  }
}

# Lifecycle policy for backup retention
resource "aws_s3_bucket_lifecycle_configuration" "backup_retention" {
  for_each = var.regions
  provider = aws.${each.key}

  bucket = aws_s3_bucket.consul_backup[each.key].id

  rule {
    id     = "backup-retention"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Enhanced KMS key with key rotation and stricter permissions
resource "aws_kms_key" "consul_backup" {
  for_each = var.regions
  provider = aws.${each.key}

  description = "KMS key for Consul backups in ${each.key}"
  deletion_window_in_days = 30
  enable_key_rotation = true
  multi_region = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Backup Service to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.consul_backup[each.key].arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "consul-backup-${each.key}"
  })
}

# IAM role for backup
resource "aws_iam_role" "consul_backup" {
  for_each = var.regions
  provider = aws.${each.key}

  name = "consul-backup-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.${each.key}.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.${each.key}.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:consul:consul-backup"
          }
        }
      }
    ]
  })
}

# IAM policy for backup
resource "aws_iam_role_policy" "consul_backup" {
  for_each = var.regions
  provider = aws.${each.key}

  name = "consul-backup-${each.key}"
  role = aws_iam_role.consul_backup[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.consul_backup[each.key].arn,
          "${aws_s3_bucket.consul_backup[each.key].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.consul_backup[each.key].arn
        ]
      }
    ]
  })
}
