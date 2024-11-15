import pytest
import boto3
import kubernetes as k8s
from kubernetes.client import ApiClient
from kubernetes.config import load_kube_config
from botocore.exceptions import ClientError

@pytest.mark.timeout(300)
def test_eks_configuration(boto3_session, k8s_client, environment, region):
    """Test EKS cluster configuration"""
    eks_client = boto3_session.client('eks')
    cluster_name = f"consul-{environment}-{region}"
    
    # Test cluster configuration
    test_cluster_config(eks_client, cluster_name)
    
    # Test node groups
    test_node_groups(eks_client, cluster_name)
    
    # Test Kubernetes API access
    test_kubernetes_api(k8s_client)
    
    # Test IAM configuration
    test_iam_roles(boto3_session, cluster_name)

def test_cluster_config(eks_client, cluster_name):
    """Test EKS cluster configuration"""
    try:
        cluster = eks_client.describe_cluster(name=cluster_name)['cluster']
        
        # Verify Kubernetes version
        assert cluster['version'] >= '1.25', "Kubernetes version too old"
        
        # Verify encryption configuration
        assert cluster['encryptionConfig'], "Encryption not configured"
        
        # Verify logging configuration
        logging = cluster['logging']['clusterLogging']
        enabled_types = [log['type'] for log in logging if log['enabled']]
        required_types = ['api', 'audit', 'authenticator']
        assert all(t in enabled_types for t in required_types), "Required logging types not enabled"
        
        # Verify network configuration
        vpc_config = cluster['resourcesVpcConfig']
        assert vpc_config['endpointPrivateAccess'], "Private endpoint access not enabled"
        assert len(vpc_config['subnetIds']) >= 3, "Not enough subnets configured"
        
    except ClientError as e:
        pytest.fail(f"Failed to test cluster config: {e}")

def test_node_groups(eks_client, cluster_name):
    """Test EKS node group configuration"""
    try:
        node_groups = eks_client.list_nodegroups(clusterName=cluster_name)['nodegroups']
        assert node_groups, "No node groups found"
        
        for ng_name in node_groups:
            ng = eks_client.describe_nodegroup(
                clusterName=cluster_name,
                nodegroupName=ng_name
            )['nodegroup']
            
            # Verify node group configuration
            assert ng['scalingConfig']['minSize'] >= 2, "Minimum node count too low"
            assert ng['amiType'] == 'AL2_x86_64', "Incorrect AMI type"
            assert ng['diskSize'] >= 50, "Disk size too small"
            
            # Verify node group tags
            tags = ng.get('tags', {})
            assert 'Environment' in tags, "Environment tag missing"
            assert 'ManagedBy' in tags, "ManagedBy tag missing"
            
    except ClientError as e:
        pytest.fail(f"Failed to test node groups: {e}")

def test_kubernetes_api(k8s_client):
    """Test Kubernetes API access"""
    try:
        # Test API access
        nodes = k8s_client.list_node()
        assert nodes.items, "No nodes found"
        
        # Test node readiness
        ready_nodes = [
            node for node in nodes.items
            if any(cond.type == 'Ready' and cond.status == 'True'
                  for cond in node.status.conditions)
        ]
        assert len(ready_nodes) >= 2, "Not enough ready nodes"
        
    except k8s.client.rest.ApiException as e:
        pytest.fail(f"Failed to test Kubernetes API: {e}")

def test_iam_roles(boto3_session, cluster_name):
    """Test IAM role configuration"""
    iam_client = boto3_session.client('iam')
    try:
        # Test cluster role
        cluster_role = iam_client.get_role(
            RoleName=f"eks-cluster-{cluster_name}"
        )['Role']
        
        # Verify trust relationship
        trust_policy = cluster_role['AssumeRolePolicyDocument']
        assert any(
            stmt['Principal']['Service'] == 'eks.amazonaws.com'
            for stmt in trust_policy['Statement']
        ), "Invalid trust relationship"
        
        # Test node role
        node_role = iam_client.get_role(
            RoleName=f"eks-node-{cluster_name}"
        )['Role']
        
        # Verify required policies
        attached_policies = iam_client.list_attached_role_policies(
            RoleName=node_role['RoleName']
        )['AttachedPolicies']
        
        required_policies = [
            'AmazonEKSWorkerNodePolicy',
            'AmazonEKS_CNI_Policy',
            'AmazonEC2ContainerRegistryReadOnly'
        ]
        
        policy_names = [p['PolicyName'] for p in attached_policies]
        assert all(
            policy in policy_names for policy in required_policies
        ), "Missing required policies"
        
    except ClientError as e:
        pytest.fail(f"Failed to test IAM roles: {e}")
