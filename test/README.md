# Multi-Region Consul Federation Tests

This directory contains Python-based tests for validating the multi-region Consul federation infrastructure.

## Prerequisites

- Python 3.8+
- AWS credentials configured
- kubectl configured with EKS cluster access
- Helm 3.0+

## Installation

Install the required Python packages:

```bash
pip install -r requirements.txt
```

## Test Structure

- `conftest.py`: Common test fixtures and configurations
- `test_consul.py`: Consul deployment and functionality tests
- `test_s3.py`: S3 backup infrastructure tests
- `test_monitoring.py`: Monitoring stack tests

## Running Tests

Run all tests:
```bash
pytest -v
```

Run specific test suite:
```bash
pytest test_consul.py -v
pytest test_s3.py -v
pytest test_monitoring.py -v
```

Run tests for specific region:
```bash
pytest --region us-west-2 -v
```

## Test Coverage

### Consul Tests
- Server deployment verification
- Mesh gateway functionality
- Basic connectivity tests

### S3 Tests
- Bucket encryption
- Versioning configuration
- Public access blocks

### Monitoring Tests
- Prometheus deployment
- Critical CloudWatch alarms
- Basic metrics collection

## Configuration

Tests can be configured using the following environment variables:
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `AWS_SESSION_TOKEN`: AWS session token (if using temporary credentials)
- `KUBECONFIG`: Path to Kubernetes config file

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
