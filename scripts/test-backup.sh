#!/bin/bash
set -e

# Test Consul backup and restore functionality
# This replaces the previous Go-based backup testing

BACKUP_BUCKET="consul-backup-test"
REGION="us-west-2"
CONSUL_NAMESPACE="consul"

# Function to check if Consul is healthy
check_consul_health() {
    kubectl get pods -n $CONSUL_NAMESPACE | grep consul-server | grep Running
    if [ $? -ne 0 ]; then
        echo "Consul is not healthy"
        exit 1
    fi
}

# Create test data
echo "Creating test data..."
kubectl exec -n $CONSUL_NAMESPACE consul-server-0 -- consul kv put test/key1 "value1"
kubectl exec -n $CONSUL_NAMESPACE consul-server-0 -- consul kv put test/key2 "value2"

# Trigger backup
echo "Triggering backup..."
kubectl create job --from=cronjob/consul-backup backup-test -n $CONSUL_NAMESPACE

# Wait for backup to complete
echo "Waiting for backup to complete..."
kubectl wait --for=condition=complete job/backup-test -n $CONSUL_NAMESPACE --timeout=300s

# Verify backup exists in S3
echo "Verifying backup in S3..."
aws s3 ls s3://$BACKUP_BUCKET/snapshots/ | grep $(date +%Y-%m-%d)
if [ $? -ne 0 ]; then
    echo "Backup not found in S3"
    exit 1
fi

# Clean test data
echo "Cleaning test data..."
kubectl exec -n $CONSUL_NAMESPACE consul-server-0 -- consul kv delete -recurse test/

# Restore from backup
echo "Testing restore..."
kubectl create job --from=cronjob/consul-restore restore-test -n $CONSUL_NAMESPACE

# Wait for restore to complete
echo "Waiting for restore to complete..."
kubectl wait --for=condition=complete job/restore-test -n $CONSUL_NAMESPACE --timeout=300s

# Verify restored data
echo "Verifying restored data..."
VALUE1=$(kubectl exec -n $CONSUL_NAMESPACE consul-server-0 -- consul kv get test/key1)
VALUE2=$(kubectl exec -n $CONSUL_NAMESPACE consul-server-0 -- consul kv get test/key2)

if [ "$VALUE1" != "value1" ] || [ "$VALUE2" != "value2" ]; then
    echo "Restore verification failed"
    exit 1
fi

echo "Backup and restore test completed successfully"
