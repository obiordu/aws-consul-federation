import pytest
import time
from kubernetes import client, config
from kubernetes.client.rest import ApiException
import subprocess
import yaml

@pytest.mark.timeout(300)
def test_consul_deployment(k8s_client, k8s_apps_client, helm_values, environment):
    """Test Consul deployment and basic functionality"""
    namespace = f"consul-{environment}"
    
    # Create namespace if it doesn't exist
    try:
        k8s_client.create_namespace(
            client.V1Namespace(metadata=client.V1ObjectMeta(name=namespace))
        )
    except ApiException as e:
        if e.status != 409:  # Ignore if namespace already exists
            raise

    # Install Consul using Helm
    helm_cmd = [
        "helm", "upgrade", "--install",
        f"consul-{environment}",
        "../../helm/consul",
        "--namespace", namespace,
        "--values", yaml.dump(helm_values)
    ]
    subprocess.run(helm_cmd, check=True)

    # Wait for Consul server pod
    wait_for_pods(k8s_client, namespace, "app=consul,component=server", 1)
    
    # Test server functionality
    test_consul_server(k8s_client, namespace)
    
    # Test mesh gateway
    test_mesh_gateway(k8s_client, namespace)

def wait_for_pods(k8s_client, namespace, label_selector, expected_count, timeout=60):
    """Wait for pods to be ready"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        pods = k8s_client.list_namespaced_pod(
            namespace=namespace,
            label_selector=label_selector
        )
        ready_pods = [
            pod for pod in pods.items
            if pod.status.phase == 'Running'
            and all(cont.ready for cont in pod.status.container_statuses)
        ]
        if len(ready_pods) >= expected_count:
            return
        time.sleep(5)
    raise TimeoutError(f"Timeout waiting for {expected_count} pods with selector {label_selector}")

def test_consul_server(k8s_client, namespace):
    """Test Consul server functionality"""
    pods = k8s_client.list_namespaced_pod(
        namespace=namespace,
        label_selector="app=consul,component=server"
    )
    assert len(pods.items) == 1, "Expected exactly one Consul server pod"
    
    # Execute Consul members command
    exec_command = [
        "consul",
        "members"
    ]
    resp = stream_pod_exec(k8s_client, pods.items[0].metadata.name, namespace, exec_command)
    assert "server" in resp, "Consul server not found in members list"

def test_mesh_gateway(k8s_client, namespace):
    """Test mesh gateway deployment"""
    pods = k8s_client.list_namespaced_pod(
        namespace=namespace,
        label_selector="app=consul,component=mesh-gateway"
    )
    assert len(pods.items) > 0, "No mesh gateway pods found"
    
    # Check mesh gateway status
    for pod in pods.items:
        assert pod.status.phase == "Running", f"Mesh gateway pod {pod.metadata.name} not running"

def stream_pod_exec(k8s_client, pod_name, namespace, command):
    """Execute command in pod and return output"""
    resp = k8s_client.read_namespaced_pod_exec(
        pod_name,
        namespace,
        command=command,
        stderr=True,
        stdin=False,
        stdout=True,
        tty=False
    )
    return resp
