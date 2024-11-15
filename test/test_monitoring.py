import pytest
import time
from kubernetes import client
import boto3

@pytest.mark.timeout(300)
def test_monitoring_configuration(k8s_client, boto3_session, environment, region):
    """Test critical monitoring components"""
    namespace = "monitoring"
    
    # Test Prometheus deployment
    test_prometheus_deployment(k8s_client, namespace)
    
    # Test CloudWatch alarms
    test_cloudwatch_alarms(boto3_session, environment, region)

def test_prometheus_deployment(k8s_client, namespace):
    """Test Prometheus deployment and configuration"""
    try:
        # Create namespace if it doesn't exist
        try:
            k8s_client.create_namespace(
                client.V1Namespace(metadata=client.V1ObjectMeta(name=namespace))
            )
        except client.rest.ApiException as e:
            if e.status != 409:  # Ignore if namespace already exists
                raise
        
        # Wait for Prometheus pod
        wait_for_prometheus(k8s_client, namespace)
        
        # Check Prometheus configuration
        config_map = k8s_client.read_namespaced_config_map(
            name="prometheus-config",
            namespace=namespace
        )
        assert "consul" in config_map.data["prometheus.yml"], "Consul scrape config not found"
        
    except client.rest.ApiException as e:
        pytest.fail(f"Failed to test Prometheus deployment: {e}")

def wait_for_prometheus(k8s_client, namespace, timeout=60):
    """Wait for Prometheus pod to be ready"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            pods = k8s_client.list_namespaced_pod(
                namespace=namespace,
                label_selector="app=prometheus"
            )
            ready_pods = [
                pod for pod in pods.items
                if pod.status.phase == 'Running'
                and all(cont.ready for cont in pod.status.container_statuses)
            ]
            if ready_pods:
                return
        except client.rest.ApiException:
            pass
        time.sleep(5)
    raise TimeoutError("Timeout waiting for Prometheus pod")

def test_cloudwatch_alarms(boto3_session, environment, region):
    """Test critical CloudWatch alarms"""
    cloudwatch = boto3_session.client('cloudwatch')
    
    # Test Consul health alarm
    alarm_name = f"consul-health-{environment}"
    try:
        alarm = cloudwatch.describe_alarms(AlarmNames=[alarm_name])['MetricAlarms'][0]
        assert alarm['ActionsEnabled'], "Alarm actions not enabled"
        assert alarm['StateValue'] in ['OK', 'INSUFFICIENT_DATA'], f"Alarm in {alarm['StateValue']} state"
    except IndexError:
        pytest.fail(f"Alarm {alarm_name} not found")
    except cloudwatch.exceptions.ResourceNotFoundException:
        pytest.fail(f"Alarm {alarm_name} not found")
