# Multi-Region Consul Federation Tests

This directory contains tests for the AWS Multi-Region Consul Federation infrastructure.

## Prerequisites

- AWS credentials configured
- kubectl configured with EKS cluster access
- Helm 3.0+

## Installation

Install the required Python packages:

```bash
pip install -r requirements.txt
```

## Test Structure

```
test/
├── terraform/              # Terraform native tests
│   ├── eks.tftest.hcl     # EKS cluster tests
│   └── consul-federation.tftest.hcl  # Federation tests
└── manifests/             # Kubernetes test manifests
    ├── cross-dc-services.yaml
    └── test-services.yaml
```

## Test Types

### Infrastructure Tests
Infrastructure testing is done using Terraform's native testing framework. These tests verify:
- Resource creation and configuration
- Module inputs and outputs
- Infrastructure relationships and dependencies

### Integration Tests
Integration testing is performed using shell scripts that verify:
- Consul federation functionality
- Backup and restore operations
- Service mesh communication
- Cross-DC service discovery

## Running Tests

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- kubectl configured with cluster access

### Running Terraform Tests
```bash
# Run all Terraform tests
terraform test

# Run specific test file
terraform test terraform/eks.tftest.hcl
```

### Running Integration Tests
```bash
# Test backup functionality
./scripts/test-backup.sh

# Test federation functionality
./scripts/test-federation.sh
```

## Test Coverage

The test suite covers:
1. Infrastructure Deployment
   - EKS cluster creation
   - Consul federation setup
   - Network configuration
   - Security settings

2. Operational Features
   - Backup and restore
   - Cross-DC communication
   - Service discovery
   - Monitoring integration

3. Security
   - TLS configuration
   - ACL system
   - Network policies
   - IAM roles

## Best Practices

1. Always run tests in a test environment first
2. Ensure proper AWS and Kubernetes credentials are configured
3. Clean up test resources after test runs
4. Monitor test execution times and optimize as needed

## Troubleshooting

Common issues and solutions:

1. AWS Credentials
```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
```

2. Kubernetes Config
```bash
export KUBECONFIG=/path/to/kubeconfig
```

3. Test Timeouts
Adjust timeouts in pytest.ini or use the --timeout command line option:
```bash
pytest --timeout=300
```
