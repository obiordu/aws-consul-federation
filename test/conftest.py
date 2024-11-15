import os
import pytest
import boto3
import kubernetes as k8s
from kubernetes.client import ApiClient
from kubernetes.config import load_kube_config

def pytest_addoption(parser):
    parser.addoption(
        "--region",
        action="store",
        default="us-west-2",
        help="AWS region to run tests against"
    )
    parser.addoption(
        "--environment",
        action="store",
        default="test",
        help="Environment name for resources"
    )

@pytest.fixture(scope="session")
def region(request):
    return request.config.getoption("--region")

@pytest.fixture(scope="session")
def environment(request):
    return request.config.getoption("--environment")

@pytest.fixture(scope="session")
def aws_credentials():
    """Credentials for AWS API calls"""
    return {
        'aws_access_key_id': os.environ.get('AWS_ACCESS_KEY_ID'),
        'aws_secret_access_key': os.environ.get('AWS_SECRET_ACCESS_KEY'),
        'aws_session_token': os.environ.get('AWS_SESSION_TOKEN')
    }

@pytest.fixture(scope="session")
def boto3_session(region, aws_credentials):
    """Create a boto3 session"""
    return boto3.Session(
        region_name=region,
        aws_access_key_id=aws_credentials['aws_access_key_id'],
        aws_secret_access_key=aws_credentials['aws_secret_access_key'],
        aws_session_token=aws_credentials['aws_session_token']
    )

@pytest.fixture(scope="session")
def k8s_client():
    """Create a Kubernetes client"""
    load_kube_config()
    return k8s.client.CoreV1Api()

@pytest.fixture(scope="session")
def k8s_apps_client():
    """Create a Kubernetes apps client for deployments"""
    load_kube_config()
    return k8s.client.AppsV1Api()

@pytest.fixture(scope="session")
def helm_values(environment):
    """Basic Helm values for Consul deployment"""
    return {
        'global': {
            'name': f'consul-{environment}',
            'datacenter': 'dc1'
        },
        'server': {
            'replicas': 1
        },
        'connectInject': {
            'enabled': True
        },
        'meshGateway': {
            'enabled': True
        },
        'tls': {
            'enabled': True
        },
        'acls': {
            'enabled': True
        }
    }
