# AWS Multi-Region Consul Federation Infrastructure

This repository contains Terraform configurations and Kubernetes manifests for deploying a production-grade, WAN-federated Consul cluster across multiple AWS regions.

## Version Requirements

- Terraform >= 1.5.0
- AWS Provider >= 5.0.0
- Kubernetes Provider >= 2.23.0
- Helm Provider >= 2.11.0
- Consul Enterprise >= 1.16.0
- Kubernetes >= 1.25.0

## Architecture Overview

This infrastructure deploys a secure, highly available Consul federation across two AWS regions:
- Primary Datacenter: US-West-2 (Oregon)
- Secondary Datacenter: US-East-1 (Virginia)

### Key Components

1. **Infrastructure Layer**
   - VPC and Networking (one per region)
   - EKS Clusters
   - IAM Roles and Policies
   - Security Groups and NACLs

2. **Consul Federation**
   - WAN Federation Configuration
   - TLS/mTLS Security
   - Gossip Encryption
   - ACL System
   - Service Mesh Configuration

3. **Security Features**
   - AWS KMS Integration
   - TLS Certificate Management
   - Network Segmentation
   - Zero-trust Network Policies

4. **Observability Stack**
   - Prometheus Monitoring
   - Grafana Dashboards
   - Alert Management
   - Logging Infrastructure

## Repository Structure

```
.
├── modules/                    # Reusable Terraform modules
│   ├── consul/                # Base Consul installation and AWS integration
│   ├── consul-federation/     # Consul federation specific configurations
│   ├── eks/                   # EKS cluster management
│   ├── monitoring/           # Monitoring stack (Prometheus, Grafana)
│   ├── networking/           # VPC and network configurations
│   └── security/             # Security configurations and policies
├── docs/                      # Documentation
├── examples/                  # Example configurations
├── test/                     # Test suites
├── main.tf                   # Root module configuration
├── variables.tf              # Input variables
└── versions.tf               # Version constraints
```

## Prerequisites

1. AWS Account with appropriate permissions
2. Terraform installed locally
3. kubectl configured
4. AWS CLI configured
5. GitHub account for CI/CD

## Getting Started

1. Clone this repository
2. Configure AWS credentials
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Review and modify variables in `environments/<region>/terraform.tfvars`
5. Deploy the infrastructure:
   ```bash
   terraform plan
   terraform apply
   ```

## Security Features

- End-to-end TLS encryption
- Gossip encryption for Consul
- AWS KMS for key management
- Network isolation
- Zero-trust network policies
- Regular security scanning in CI/CD

## Disaster Recovery

- Automated backups
- Cross-region failover
- Data replication
- Recovery procedures documented in `/docs/disaster-recovery.md`

## Monitoring and Alerting

- Prometheus metrics
- Grafana dashboards
- Alert configurations
- Log aggregation

## CI/CD Pipeline

The repository includes GitHub Actions workflows for:
- Terraform validation
- Security scanning (tfsec)
- Infrastructure testing
- Automated deployments

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit changes
4. Create a pull request

## License

MIT License

## Support

For issues and feature requests, please create a GitHub issue.
