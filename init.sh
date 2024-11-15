#!/bin/bash
set -euo pipefail

# Check prerequisites
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting." >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed. Aborting." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "Helm is required but not installed. Aborting." >&2; exit 1; }

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Create terraform.tfvars if it doesn't exist
if [ ! -f terraform.tfvars ]; then
    echo "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "Please edit terraform.tfvars with your values before proceeding."
    exit 0
fi

# Verify required variables
required_vars=(
    "environment"
    "domain_name"
)

for var in "${required_vars[@]}"; do
    if ! grep -q "^${var} = " terraform.tfvars; then
        echo "Error: Required variable '${var}' not found in terraform.tfvars"
        exit 1
    fi
done

# Create backend configuration if needed
if [ ! -f backend.tf ]; then
    cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket = "terraform-state-consul-federation"
    key    = "terraform.tfstate"
    region = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt = true
  }
}
EOF
    echo "Created backend.tf. Please update with your S3 bucket and DynamoDB table."
    exit 0
fi

# Create S3 bucket and DynamoDB table for backend if they don't exist
bucket_name=$(grep 'bucket = ' backend.tf | cut -d'"' -f2)
table_name=$(grep 'dynamodb_table = ' backend.tf | cut -d'"' -f2)
region=$(grep 'region = ' backend.tf | cut -d'"' -f2)

if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
    echo "Creating S3 bucket for Terraform state..."
    aws s3api create-bucket \
        --bucket "$bucket_name" \
        --region "$region" \
        --create-bucket-configuration LocationConstraint="$region"
    
    aws s3api put-bucket-versioning \
        --bucket "$bucket_name" \
        --versioning-configuration Status=Enabled
    
    aws s3api put-bucket-encryption \
        --bucket "$bucket_name" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
fi

if ! aws dynamodb describe-table --table-name "$table_name" >/dev/null 2>&1; then
    echo "Creating DynamoDB table for Terraform locks..."
    aws dynamodb create-table \
        --table-name "$table_name" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
        --region "$region"
fi

echo "Initialization complete. You can now run 'terraform plan' to review changes."
