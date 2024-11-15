# Troubleshooting Guide

## Common Issues and Solutions

### 1. Deployment Issues

#### EKS Cluster Creation Fails
```
Problem: EKS cluster creation times out or fails
Solution:
1. Check IAM permissions
2. Verify VPC subnet configuration
3. Ensure service-linked role exists
```

#### Consul Server Pod Crashes
```
Problem: Consul server pods fail to start or crash
Solution:
1. Check resource limits
2. Verify storage class exists
3. Review pod logs: kubectl logs -n consul <pod-name>
4. Ensure gossip key is properly set
```

#### TLS Certificate Issues
```
Problem: Services fail to communicate due to TLS errors
Solution:
1. Verify ACM certificate status
2. Check Consul CA configuration
3. Ensure service accounts have proper annotations
4. Review certificate expiration dates
```

### 2. Federation Issues

#### Mesh Gateway Connection Failures
```
Problem: Services cannot communicate across regions
Solution:
1. Check mesh gateway logs
2. Verify VPC peering status
3. Test network connectivity
4. Review security group rules
```

#### Service Discovery Issues
```
Problem: Services cannot discover peers in other regions
Solution:
1. Verify WAN federation setup
2. Check DNS configuration
3. Test Route53 health checks
4. Review service registration
```

### 3. Performance Issues

#### High Latency
```
Problem: Cross-region requests have high latency
Solution:
1. Monitor network metrics
2. Check resource utilization
3. Review connection pooling
4. Optimize service placement
```

#### Resource Constraints
```
Problem: Nodes or pods show resource pressure
Solution:
1. Review resource requests/limits
2. Check node autoscaling
3. Monitor pod evictions
4. Adjust HPA settings
```

### 4. Monitoring Issues

#### Missing Metrics
```
Problem: Prometheus is not collecting all metrics
Solution:
1. Check service monitor configuration
2. Verify endpoint annotations
3. Review scrape configs
4. Check Prometheus resources
```

#### Alert Storm
```
Problem: Too many alerts firing simultaneously
Solution:
1. Review alert thresholds
2. Check alert grouping
3. Adjust alert timing
4. Implement alert suppression
```

### 5. Backup/Restore Issues

#### Backup Failure
```
Problem: Automated backups are failing
Solution:
1. Check S3 permissions
2. Verify snapshot API access
3. Review backup script logs
4. Check encryption keys
```

#### Restore Failure
```
Problem: Restore operation fails
Solution:
1. Verify backup integrity
2. Check restore permissions
3. Review cluster state
4. Ensure version compatibility
```

## Diagnostic Commands

### Kubernetes
```bash
# Check pod status
kubectl get pods -n consul

# View pod logs
kubectl logs -n consul <pod-name>

# Check events
kubectl get events -n consul

# Describe resource
kubectl describe <resource-type> <resource-name> -n consul
```

### Consul
```bash
# Check member status
consul members -wan

# View service catalog
consul catalog services

# Check ACL status
consul acl token list

# Verify TLS
consul tls verify
```

### AWS
```bash
# Check VPC peering
aws ec2 describe-vpc-peering-connections

# View Route53 health checks
aws route53 list-health-checks

# Check EKS status
aws eks describe-cluster --name <cluster-name>

# View ACM certificates
aws acm list-certificates
```

## Health Check Script
```bash
#!/bin/bash

check_component() {
    component=$1
    command=$2
    
    echo "Checking $component..."
    if eval "$command"; then
        echo "✅ $component is healthy"
    else
        echo "❌ $component check failed"
        return 1
    fi
}

# Check EKS clusters
check_component "EKS Primary" "aws eks describe-cluster --name primary"
check_component "EKS Secondary" "aws eks describe-cluster --name secondary"

# Check Consul servers
check_component "Consul Primary" "kubectl get pods -n consul -l component=server"
check_component "Consul Secondary" "kubectl get pods -n consul -l component=server --context secondary"

# Check mesh gateways
check_component "Mesh Gateway Primary" "kubectl get pods -n consul -l component=mesh-gateway"
check_component "Mesh Gateway Secondary" "kubectl get pods -n consul -l component=mesh-gateway --context secondary"

# Check monitoring
check_component "Prometheus" "kubectl get pods -n monitoring -l app=prometheus"
check_component "Grafana" "kubectl get pods -n monitoring -l app=grafana"
```

## Recovery Procedures

### Full Region Failure
1. Verify region health status
2. Trigger Route53 failover
3. Scale up secondary region
4. Update DNS records
5. Verify service health
6. Monitor recovery metrics

### Consul Server Recovery
1. Stop affected servers
2. Restore from backup
3. Join WAN federation
4. Verify replication
5. Update service configs
6. Monitor cluster health

### Data Corruption Recovery
1. Identify corruption scope
2. Stop affected services
3. Restore from last known good backup
4. Verify data integrity
5. Resume service operations
6. Update monitoring alerts

## Support Information

### Logging Locations
- Consul Servers: `/consul/data/server.log`
- Mesh Gateways: `/consul/data/mesh-gateway.log`
- Prometheus: `/prometheus/data/`
- Application Logs: CloudWatch Logs

### Metrics Endpoints
- Consul Metrics: `:8500/v1/agent/metrics`
- Mesh Gateway: `:19000/stats`
- Prometheus: `:9090/metrics`
- Custom Metrics: `:8080/metrics`

### Support Contacts
- Infrastructure Team: infrastructure@company.com
- Security Team: security@company.com
- On-Call: +1-xxx-xxx-xxxx
