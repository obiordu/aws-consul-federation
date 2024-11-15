# Technology Stack

## Core Languages
- HCL (HashiCorp Configuration Language)
- Shell scripting (Bash)
- YAML

## Infrastructure as Code
- Terraform >= 1.5.0
  - AWS Provider >= 5.0.0
  - Kubernetes Provider >= 2.23.0
  - Helm Provider >= 2.11.0
  - Consul Provider >= 2.18.0

## Container & Orchestration
- Docker
- Kubernetes >= 1.25.0
- Helm >= 3.12.0

## Service Mesh
- Consul OSS 1.16.0
- Envoy Proxy

## Cloud Platform (AWS)
### Core Services
- EKS (Elastic Kubernetes Service)
- EC2
- VPC
- S3
- CloudWatch
- IAM
- Route53
- ACM (AWS Certificate Manager)

### Networking
- Transit Gateway
- VPC Peering
- Network Load Balancer
- Security Groups
- NACLs

## Testing Framework
### Infrastructure Testing
- Terraform native testing (tftest.hcl)
- Shell script integration tests
- AWS CloudWatch Synthetics

### Security Testing
- AWS Config Rules
- AWS Security Hub
- IAM Access Analyzer

## Monitoring & Observability
- Prometheus
  - Node Exporter
  - Alert Manager
- Grafana
  - Loki
  - Tempo
- AWS CloudWatch
  - Container Insights
  - Log Insights
- Consul UI

## Security Components
- AWS KMS
- AWS Secrets Manager
- TLS/SSL Certificates (ACM)
- IAM Roles & Policies
- Network Policies
- Security Groups
- NACLs
- AWS WAF
- AWS Shield

## Backup & Recovery
- AWS Backup
- S3 Cross-Region Replication
- Consul Snapshots
- EKS Backup Controller

## CI/CD & Version Control
- GitHub Actions
- Git
- AWS CodeBuild
- Docker Hub

## Documentation
- Markdown
- Draw.io (Architecture diagrams)
- Terraform documentation
- AWS Well-Architected Framework

## Cost Management
- AWS Cost Explorer
- AWS Budgets
- AWS Cost and Usage Report
