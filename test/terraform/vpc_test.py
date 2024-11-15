import pytest
import boto3
from botocore.exceptions import ClientError

@pytest.mark.timeout(180)
def test_vpc_configuration(boto3_session, environment, region):
    """Test VPC configuration and connectivity"""
    ec2_client = boto3_session.client('ec2')
    vpc_name = f"consul-{environment}-{region}"
    
    # Test VPC configuration
    vpc_id = get_vpc_by_name(ec2_client, vpc_name)
    test_vpc_subnets(ec2_client, vpc_id)
    test_vpc_routing(ec2_client, vpc_id)
    test_vpc_security(ec2_client, vpc_id)

def get_vpc_by_name(ec2_client, vpc_name):
    """Get VPC ID by name tag"""
    try:
        response = ec2_client.describe_vpcs(
            Filters=[
                {
                    'Name': 'tag:Name',
                    'Values': [vpc_name]
                }
            ]
        )
        if not response['Vpcs']:
            pytest.fail(f"VPC {vpc_name} not found")
        return response['Vpcs'][0]['VpcId']
    except ClientError as e:
        pytest.fail(f"Failed to get VPC: {e}")

def test_vpc_subnets(ec2_client, vpc_id):
    """Test VPC subnet configuration"""
    try:
        subnets = ec2_client.describe_subnets(
            Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
        )['Subnets']
        
        # Verify we have both public and private subnets
        public_subnets = [s for s in subnets if any(
            t['Key'] == 'Tier' and t['Value'] == 'Public'
            for t in ec2_client.describe_tags(
                Filters=[{'Name': 'resource-id', 'Values': [s['SubnetId']]}]
            ).get('Tags', [])
        )]
        private_subnets = [s for s in subnets if any(
            t['Key'] == 'Tier' and t['Value'] == 'Private'
            for t in ec2_client.describe_tags(
                Filters=[{'Name': 'resource-id', 'Values': [s['SubnetId']]}]
            ).get('Tags', [])
        )]
        
        assert len(public_subnets) >= 2, "Not enough public subnets"
        assert len(private_subnets) >= 2, "Not enough private subnets"
        
    except ClientError as e:
        pytest.fail(f"Failed to test subnets: {e}")

def test_vpc_routing(ec2_client, vpc_id):
    """Test VPC routing configuration"""
    try:
        # Get route tables
        route_tables = ec2_client.describe_route_tables(
            Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
        )['RouteTables']
        
        # Verify internet gateway for public subnets
        public_routes = [rt for rt in route_tables if any(
            route.get('GatewayId', '').startswith('igw-')
            for route in rt['Routes']
        )]
        assert public_routes, "No public route tables found"
        
        # Verify NAT gateway for private subnets
        private_routes = [rt for rt in route_tables if any(
            route.get('NatGatewayId', '').startswith('nat-')
            for route in rt['Routes']
        )]
        assert private_routes, "No private route tables found"
        
    except ClientError as e:
        pytest.fail(f"Failed to test routing: {e}")

def test_vpc_security(ec2_client, vpc_id):
    """Test VPC security configuration"""
    try:
        # Test Network ACLs
        nacls = ec2_client.describe_network_acls(
            Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
        )['NetworkAcls']
        
        # Verify default deny rules
        for nacl in nacls:
            entries = sorted(nacl['Entries'], key=lambda x: x['RuleNumber'])
            assert any(
                entry['RuleNumber'] == 32767 and entry['RuleAction'] == 'deny'
                for entry in entries
            ), "No default deny rule found in NACL"
        
        # Test Security Groups
        security_groups = ec2_client.describe_security_groups(
            Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
        )['SecurityGroups']
        
        # Verify no overly permissive rules
        for sg in security_groups:
            for rule in sg['IpPermissions']:
                cidrs = [ip_range['CidrIp'] for ip_range in rule.get('IpRanges', [])]
                assert '0.0.0.0/0' not in cidrs, f"Security group {sg['GroupId']} has overly permissive inbound rule"
                
    except ClientError as e:
        pytest.fail(f"Failed to test security: {e}")
