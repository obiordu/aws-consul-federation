# Frequently Asked Questions (FAQ)

## General Questions

### Q: What is this repository for?
A: This repository contains Terraform configurations and supporting scripts to deploy a production-grade, WAN-federated Consul service mesh across two AWS regions (Oregon and Virginia).

### Q: What are the main components?
A: The main components are:
- EKS clusters in two regions
- Consul servers (primary and secondary)
- Service mesh configuration
- Monitoring stack (Prometheus/Grafana)
- Backup/restore automation

### Q: What versions are supported?
A: The infrastructure supports:
- Terraform >= 1.5.0
- Consul OSS >= 1.16.0
- Kubernetes >= 1.25.0
- AWS Provider >= 5.0.0

## Setup and Configuration

### Q: How long does initial deployment take?
A: Initial deployment typically takes 30-45 minutes, with most time spent on EKS cluster creation.

### Q: What AWS permissions are needed?
A: Required permissions include:
- EKS full access
- EC2 full access
- IAM role creation
- VPC management
- S3 bucket access
- KMS key management

### Q: How do I customize the deployment?
A: Edit `terraform.tfvars` to customize:
- AWS regions
- VPC CIDR ranges
- Cluster sizes
- Backup schedules
- Monitoring configuration

## Security

### Q: Is the deployment secure by default?
A: Yes, security features include:
- TLS encryption everywhere
- mTLS for service mesh
- Network policies
- IAM roles with least privilege
- Encrypted backups
- ACL system enabled

### Q: How are secrets managed?
A: Secrets are managed through:
- AWS KMS for encryption keys
- Kubernetes secrets for sensitive data
- Consul ACL system for access control
- Encrypted S3 buckets for backups

## Monitoring

### Q: What metrics are collected?
A: Key metrics include:
- Consul server health
- Service mesh performance
- Cross-DC latency
- Resource utilization
- Backup status

### Q: How do I access dashboards?
A: Grafana dashboards are accessible via:
1. Get the Grafana URL:
   ```bash
   kubectl get svc -n monitoring grafana
   ```
2. Retrieve initial credentials from AWS Secrets Manager
3. Access via browser with provided URL

## Disaster Recovery

### Q: How often are backups taken?
A: Automated backups run every 6 hours with:
- Cross-region replication
- 30-day retention
- Encryption at rest
- Automated testing

### Q: What's the recovery time?
A: Recovery times vary by scenario:
- Single node failure: ~5 minutes
- Full DC failure: ~15 minutes
- Region failure: ~30 minutes
- Data corruption: ~45 minutes

## Troubleshooting

### Q: Common deployment issues?
A: Common issues include:
1. AWS quota limits
2. IAM permission issues
3. VPC subnet availability
4. Kubernetes version mismatches

### Q: How do I check cluster health?
A: Use these commands:
```bash
# Check Consul servers
kubectl get pods -n consul

# Check federation status
kubectl exec -it consul-server-0 -n consul -- consul members -wan

# Check service mesh
kubectl get pods -n consul-system
```

## Maintenance

### Q: How do I update Consul?
A: Update process:
1. Update version in variables
2. Run Terraform plan/apply
3. Monitor rollout
4. Verify federation status

### Q: How do I scale the cluster?
A: Scaling options:
1. EKS nodes: Adjust `desired_size` in variables
2. Consul servers: Modify `server_replicas`
3. Apply changes with Terraform

## Cost Management

### Q: What's the typical cost?
A: Monthly costs (USD):
- EKS: ~$146
- EC2: ~$140-280
- Load Balancers: ~$40
- Data Transfer: ~$50-100
- S3: ~$5-10
Total: ~$400-600

### Q: How can I reduce costs?
A: Cost optimization options:
1. Use smaller instance types
2. Reduce number of nodes
3. Optimize backup retention
4. Use Spot instances where possible

## Support

### Q: How do I get help?
A: Support options:
1. Create GitHub issues
2. Check documentation
3. Review troubleshooting guide
4. Consult AWS/Consul documentation

### Q: How do I contribute?
A: Contribution steps:
1. Fork repository
2. Create feature branch
3. Make changes
4. Submit pull request
5. Follow contribution guidelines
