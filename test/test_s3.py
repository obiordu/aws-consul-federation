import pytest
import boto3
from botocore.exceptions import ClientError

@pytest.mark.timeout(180)
def test_s3_configuration(boto3_session, environment, region):
    """Test critical S3 bucket configurations"""
    s3_client = boto3_session.client('s3')
    bucket_name = f"consul-backup-{environment}-{region}"
    
    # Test bucket encryption
    test_bucket_encryption(s3_client, bucket_name)
    
    # Test bucket versioning
    test_bucket_versioning(s3_client, bucket_name)
    
    # Test public access block
    test_public_access_block(s3_client, bucket_name)

def test_bucket_encryption(s3_client, bucket_name):
    """Test S3 bucket encryption configuration"""
    try:
        encryption = s3_client.get_bucket_encryption(Bucket=bucket_name)
        rules = encryption['ServerSideEncryptionConfiguration']['Rules']
        assert any(
            rule['ApplyServerSideEncryptionByDefault']['SSEAlgorithm'] == 'aws:kms'
            for rule in rules
        ), "KMS encryption not enabled"
    except ClientError as e:
        if e.response['Error']['Code'] == 'ServerSideEncryptionConfigurationNotFoundError':
            pytest.fail("Bucket encryption not configured")
        raise

def test_bucket_versioning(s3_client, bucket_name):
    """Test S3 bucket versioning configuration"""
    versioning = s3_client.get_bucket_versioning(Bucket=bucket_name)
    assert versioning.get('Status') == 'Enabled', "Bucket versioning not enabled"

def test_public_access_block(s3_client, bucket_name):
    """Test S3 bucket public access block configuration"""
    try:
        public_access = s3_client.get_public_access_block(Bucket=bucket_name)
        config = public_access['PublicAccessBlockConfiguration']
        
        assert config['BlockPublicAcls'], "BlockPublicAcls not enabled"
        assert config['BlockPublicPolicy'], "BlockPublicPolicy not enabled"
        assert config['IgnorePublicAcls'], "IgnorePublicAcls not enabled"
        assert config['RestrictPublicBuckets'], "RestrictPublicBuckets not enabled"
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchPublicAccessBlockConfiguration':
            pytest.fail("Public access block not configured")
        raise
