# Troubleshooting Guide

This guide helps diagnose and resolve common issues in the AWS Multi-Region Consul Federation infrastructure.

## Quick Diagnostics

### 1. Infrastructure Health Check

```bash
# Check EKS clusters
aws eks describe-cluster --name consul-federation-primary --region us-west-2
aws eks describe-cluster --name consul-federation-secondary --region us-east-1

# Check Consul servers
kubectl get pods -n consul
kubectl exec -it consul-server-0 -n consul -- consul members

# Check federation status
kubectl exec -it consul-server-0 -n consul -- consul members -wan
```

### 2. Common Status Codes

| Status | Description | Action |
|--------|-------------|--------|
| 500 | Internal Server Error | Check Consul server logs |
| 503 | Service Unavailable | Verify service mesh status |
| 403 | Forbidden | Check ACL tokens |
| 429 | Too Many Requests | Review rate limits |

## Common Issues

### 1. EKS Cluster Creation Fails

**Symptoms**:
- Terraform apply fails during EKS creation
- AWS API errors
- Timeout errors

**Solutions**:
1. Check AWS quotas:
   ```bash
   aws service-quotas get-service-quota \
     --service-code eks \
     --quota-code L-1194D53C
   ```

2. Verify IAM permissions
3. Check VPC subnet availability
4. Review security group rules

### 2. Consul Server Issues

**Symptoms**:
- Pods in CrashLoopBackOff
- Leadership election problems
- Replication delays

**Solutions**:
1. Check logs:
   ```bash
   kubectl logs consul-server-0 -n consul
   ```

2. Verify configuration:
   ```bash
   kubectl describe configmap consul-server-config -n consul
   ```

3. Check resources:
   ```bash
   kubectl top pods -n consul
   ```

### 3. Federation Problems

**Symptoms**:
- WAN gossip failures
- Cross-DC service discovery issues
- Replication delays

**Solutions**:
1. Check WAN status:
   ```bash
   kubectl exec consul-server-0 -n consul -- consul operator raft list-peers
   ```

2. Verify network connectivity:
   ```bash
   kubectl exec consul-server-0 -n consul -- nc -zv consul-server.dc2.consul 8302
   ```

3. Review TLS certificates:
   ```bash
   kubectl exec consul-server-0 -n consul -- consul tls cert-info
   ```

### 4. Service Mesh Issues

**Symptoms**:
- Service discovery failures
- mTLS errors
- Proxy injection failures

**Solutions**:
1. Check Envoy status:
   ```bash
   kubectl logs <pod-name> -c consul-dataplane -n <namespace>
   ```

2. Verify intentions:
   ```bash
   kubectl exec -it consul-server-0 -n consul -- consul intention list
   ```

3. Test connectivity:
   ```bash
   kubectl exec -it <pod-name> -n <namespace> -- curl localhost:19000/clusters
   ```

## Monitoring Issues

### 1. Prometheus Problems

**Symptoms**:
- Missing metrics
- Scrape failures
- High cardinality alerts

**Solutions**:
1. Check Prometheus status:
   ```bash
   kubectl get pods -n monitoring
   kubectl logs prometheus-server-0 -n monitoring
   ```

2. Verify service discovery:
   ```bash
   kubectl get servicemonitors -A
   ```

3. Review storage:
   ```bash
   kubectl get pvc -n monitoring
   ```

### 2. Grafana Issues

**Symptoms**:
- Dashboard loading failures
- Authentication problems
- Data source errors

**Solutions**:
1. Check Grafana logs:
   ```bash
   kubectl logs grafana-0 -n monitoring
   ```

2. Verify data sources:
   ```bash
   kubectl get secrets -n monitoring | grep grafana
   ```

3. Test Prometheus connection:
   ```bash
   curl -I http://prometheus-server.monitoring:9090/api/v1/query
   ```

## Backup/Restore Issues

### 1. Backup Failures

**Symptoms**:
- Failed backup jobs
- Incomplete snapshots
- S3 upload errors

**Solutions**:
1. Check backup logs:
   ```bash
   kubectl logs backup-job-xxxxx -n consul
   ```

2. Verify S3 access:
   ```bash
   aws s3 ls s3://consul-backups-bucket/
   ```

3. Test IAM permissions:
   ```bash
   aws sts get-caller-identity
   ```

### 2. Restore Problems

**Symptoms**:
- Restore job failures
- Data inconsistency
- ACL token issues

**Solutions**:
1. Check restore logs:
   ```bash
   kubectl logs restore-job-xxxxx -n consul
   ```

2. Verify snapshot:
   ```bash
   consul snapshot inspect backup.snap
   ```

3. Test restore locally:
   ```bash
   consul snapshot restore -http-addr=https://localhost:8500 backup.snap
   ```

## Performance Issues

### 1. High Latency

**Symptoms**:
- Slow service responses
- Increased error rates
- Timeout errors

**Solutions**:
1. Check resource usage:
   ```bash
   kubectl top pods -n consul
   ```

2. Monitor network metrics:
   ```bash
   kubectl exec consul-server-0 -n consul -- consul monitor
   ```

3. Review Envoy statistics:
   ```bash
   curl localhost:19000/stats
   ```

### 2. Memory Problems

**Symptoms**:
- OOMKilled pods
- High memory usage
- Slow performance

**Solutions**:
1. Check memory usage:
   ```bash
   kubectl describe node <node-name>
   ```

2. Review limits:
   ```bash
   kubectl describe pod <pod-name> -n consul
   ```

3. Adjust resources:
   ```bash
   kubectl edit statefulset consul-server -n consul
   ```

## Security Issues

### 1. TLS Problems

**Symptoms**:
- Certificate errors
- Connection refused
- Handshake failures

**Solutions**:
1. Check certificate validity:
   ```bash
   consul tls cert-info -ca-file ca.pem
   ```

2. Verify trust chain:
   ```bash
   openssl verify -CAfile ca.pem cert.pem
   ```

3. Test TLS connection:
   ```bash
   openssl s_client -connect consul-server:8501
   ```

### 2. ACL Issues

**Symptoms**:
- Permission denied
- Token errors
- Access problems

**Solutions**:
1. Check token validity:
   ```bash
   consul acl token read -id <token-id>
   ```

2. Review policies:
   ```bash
   consul acl policy list
   ```

3. Test permissions:
   ```bash
   consul acl token update -id <token-id> -policy-name <policy>
   ```

## Network Issues

### 1. DNS Problems

**Symptoms**:
- Service discovery failures
- Name resolution errors
- CoreDNS issues

**Solutions**:
1. Check CoreDNS:
   ```bash
   kubectl logs -n kube-system -l k8s-app=kube-dns
   ```

2. Test DNS resolution:
   ```bash
   kubectl run -it --rm debug --image=busybox -- nslookup consul-server.consul
   ```

3. Verify DNS policy:
   ```bash
   kubectl describe configmap coredns -n kube-system
   ```

### 2. Connectivity Issues

**Symptoms**:
- Network timeouts
- Connection refused
- Routing problems

**Solutions**:
1. Check network policies:
   ```bash
   kubectl get networkpolicies -A
   ```

2. Test connectivity:
   ```bash
   kubectl exec -it <pod> -- nc -zv <service> <port>
   ```

3. Review VPC peering:
   ```bash
   aws ec2 describe-vpc-peering-connections
   ```

## References

- [Consul Troubleshooting](https://www.consul.io/docs/troubleshoot)
- [EKS Troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [Kubernetes Debugging](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-application/)
- [Envoy Debug](https://www.envoyproxy.io/docs/envoy/latest/operations/admin)
