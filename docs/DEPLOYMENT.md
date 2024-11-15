# Deployment Guide

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- kubectl >= 1.25.0
- helm >= 3.0.0

## Infrastructure Components

1. **VPC and Networking**
   - Two VPCs (us-west-2 and us-east-1)
   - VPC peering
   - Private and public subnets
   - NAT gateways
   - Security groups

2. **EKS Clusters**
   - Managed node groups
   - IAM roles
   - IRSA configuration
   - Cluster autoscaling

3. **Consul Federation**
   - Primary datacenter (us-west-2)
   - Secondary datacenter (us-east-1)
   - Mesh gateways
   - Service mesh configuration

4. **DNS and Failover**
   - Route53 health checks
   - Failover routing
   - Service discovery
   - Regional endpoints

## Deployment Steps

1. **Initialize Infrastructure**
   ```bash
   terraform init
   terraform workspace new <environment>
   ```

2. **Configure Variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Deploy Infrastructure**
   ```bash
   terraform plan
   terraform apply
   ```

4. **Configure kubectl**
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name primary-cluster
   aws eks update-kubeconfig --region us-east-1 --name secondary-cluster
   ```

5. **Verify Deployment**
   ```bash
   kubectl get pods -n consul
   consul members -wan
   ```

## Failover Testing

1. **Test Automatic Failover**
   ```bash
   # Simulate primary failure
   kubectl scale deployment consul-server -n consul --replicas=0
   
   # Verify failover
   dig consul.domain.com
   ```

2. **Manual Failover**
   ```bash
   # Update Route53 health check
   aws route53 update-health-check --health-check-id <id> --disabled
   ```

## Monitoring

1. **Access Dashboards**
   - Grafana: https://monitoring.domain.com/grafana
   - Prometheus: https://monitoring.domain.com/prometheus
   - Consul UI: https://consul.domain.com

2. **Health Checks**
   ```bash
   ./scripts/health_check.sh
   ```

## Backup and Recovery

1. **Create Backup**
   ```bash
   export BACKUP_BUCKET="consul-backups"
   ./scripts/backup.sh
   ```

2. **Restore from Backup**
   ```bash
   export BACKUP_FILE="consul-backup-20231101.snap.gpg"
   ./scripts/restore.sh
   ```

## Troubleshooting

1. **Common Issues**
   - EKS cluster access
   - VPC peering connection
   - DNS resolution
   - TLS certificate issues

2. **Debugging Steps**
   ```bash
   # Check Consul server logs
   kubectl logs -n consul -l component=server
   
   # Verify mesh gateway status
   kubectl logs -n consul -l component=mesh-gateway
   
   # Test cross-DC communication
   consul members -wan
   ```

3. **Support Resources**
   - AWS Documentation
   - Consul Documentation
   - GitHub Issues
   - Community Forums
