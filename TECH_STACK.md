# Technology Stack

## Core Languages
- Python 3.8+ (Primary language for all components)
- HCL (HashiCorp Configuration Language)
- YAML
- Shell scripting (Bash/PowerShell)

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
- EKS (Elastic Kubernetes Service)
- EC2
- VPC
- S3
- CloudWatch
- IAM
- Route53
- ACM (AWS Certificate Manager)

## Python Packages
### Core Dependencies
```
boto3==1.29.3          # AWS SDK
kubernetes==28.1.0     # Kubernetes API
python-consul2==0.1.5  # Consul API
pyyaml==6.0.1         # YAML parsing
requests==2.31.0       # HTTP client
cryptography==41.0.5   # TLS/encryption
aiohttp==3.9.1        # Async HTTP client
tenacity==8.2.3       # Retries and backoff
structlog==23.2.0     # Structured logging
```

### Testing Dependencies
```
pytest==7.4.3         # Testing framework
pytest-timeout==2.2.0 # Test timeouts
pytest-xdist==3.3.1   # Parallel testing
pytest-env==1.0.1     # Environment variables
pytest-asyncio==0.21.1 # Async test support
pytest-cov==4.1.0     # Coverage reporting
```

### Development Dependencies
```
black==23.11.0        # Code formatting
isort==5.12.0        # Import sorting
flake8==6.1.0        # Linting
mypy==1.7.0          # Type checking
pre-commit==3.5.0    # Git hooks
```

### Infrastructure Testing
```
moto==4.2.7          # AWS service mocking
responses==0.24.1    # HTTP mocking
pytest-kubernetes==0.3.0  # K8s testing utilities
```

## Monitoring & Observability
- Prometheus
- Grafana
- AWS CloudWatch
- Consul UI

## Security Tools
- AWS KMS
- TLS/SSL Certificates
- IAM Roles & Policies
- Network Policies
- Security Groups
- NACLs

## CI/CD
- GitHub Actions
- AWS CodeBuild
- Docker Hub

## Documentation
- Markdown
- PlantUML (Architecture diagrams)
- Swagger/OpenAPI (API documentation)
