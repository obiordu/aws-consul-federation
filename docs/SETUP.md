# Setup Guide

This guide provides detailed instructions for setting up the AWS Multi-Region Consul Federation infrastructure.

## Initial Setup

### 1. AWS Account Setup

1. Create an AWS account if you don't have one
2. Create an IAM user with appropriate permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "eks:*",
           "ec2:*",
           "iam:*",
           "s3:*",
           "kms:*",
           "elasticloadbalancing:*"
         ],
         "Resource": "*"
       }
     ]
   }
   ```
3. Configure AWS CLI with credentials

### 2. Tool Installation

1. Install AWS CLI:
   ```bash
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. Install Terraform:
   ```bash
   wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
   unzip terraform_1.5.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

3. Install kubectl:
   ```bash
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

4. Install Helm:
   ```bash
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

### 3. Repository Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/aws-consul-federation.git
   cd aws-consul-federation
   ```

2. Create terraform.tfvars:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit terraform.tfvars with your values:
   ```hcl
   aws_region_primary     = "us-west-2"
   aws_region_secondary   = "us-east-1"
   environment           = "production"
   vpc_cidr_primary      = "10.0.0.0/16"
   vpc_cidr_secondary    = "10.1.0.0/16"
   cluster_name          = "consul-federation"
   ```

## Deployment

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Plan the Deployment

```bash
terraform plan
```

Review the plan carefully to ensure it matches your expectations.

### 3. Apply the Configuration

```bash
terraform apply
```

### 4. Verify the Deployment

1. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name consul-federation-primary
   aws eks update-kubeconfig --region us-east-1 --name consul-federation-secondary
   ```

2. Check Consul status:
   ```bash
   kubectl get pods -n consul
   kubectl exec -it consul-server-0 -n consul -- consul members
   ```

3. Verify federation:
   ```bash
   kubectl exec -it consul-server-0 -n consul -- consul members -wan
   ```

## Post-Deployment Tasks

1. Configure DNS (if needed)
2. Set up monitoring dashboards
3. Test backup and restore procedures
4. Configure alerts
5. Document any custom configurations

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

## Next Steps

1. Deploy sample applications
2. Set up CI/CD pipelines
3. Configure backup schedules
4. Set up monitoring alerts

## Security Considerations

1. Rotate credentials regularly
2. Review security groups
3. Monitor AWS CloudTrail
4. Regularly update dependencies

For more detailed security information, see [SECURITY.md](SECURITY.md).
