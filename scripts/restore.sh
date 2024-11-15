#!/bin/bash
set -euo pipefail

# Default values
REGION="us-west-2"
NAMESPACE="consul"
BACKUP_BUCKET=""
SNAPSHOT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --region)
      REGION="$2"
      shift
      shift
      ;;
    --namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    --bucket)
      BACKUP_BUCKET="$2"
      shift
      shift
      ;;
    --snapshot)
      SNAPSHOT="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "$BACKUP_BUCKET" ]]; then
  echo "Error: --bucket parameter is required"
  exit 1
fi

# If no specific snapshot is provided, use the latest
if [[ -z "$SNAPSHOT" ]]; then
  echo "No snapshot specified, finding latest..."
  SNAPSHOT=$(aws s3 ls s3://${BACKUP_BUCKET}/consul-snapshots/${NAMESPACE}/ | sort | tail -n 1 | awk '{print $4}')
  if [[ -z "$SNAPSHOT" ]]; then
    echo "Error: No snapshots found in s3://${BACKUP_BUCKET}/consul-snapshots/${NAMESPACE}/"
    exit 1
  fi
fi

echo "Using snapshot: ${SNAPSHOT}"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf ${TEMP_DIR}' EXIT

# Download snapshot
echo "Downloading snapshot from S3..."
aws s3 cp s3://${BACKUP_BUCKET}/consul-snapshots/${NAMESPACE}/${SNAPSHOT} ${TEMP_DIR}/restore.snap

# Verify snapshot integrity
echo "Verifying snapshot..."
kubectl exec -n ${NAMESPACE} consul-server-0 -- consul snapshot inspect ${TEMP_DIR}/restore.snap

# Stop Consul servers
echo "Scaling down Consul servers..."
kubectl scale statefulset/consul-server -n ${NAMESPACE} --replicas=0

# Wait for shutdown
echo "Waiting for servers to stop..."
kubectl wait --for=delete pod/consul-server-0 -n ${NAMESPACE} --timeout=300s

# Start first server
echo "Starting first server..."
kubectl scale statefulset/consul-server -n ${NAMESPACE} --replicas=1

# Wait for server to be ready
echo "Waiting for server to be ready..."
kubectl wait --for=condition=ready pod/consul-server-0 -n ${NAMESPACE} --timeout=300s

# Restore snapshot
echo "Restoring snapshot..."
kubectl cp ${TEMP_DIR}/restore.snap ${NAMESPACE}/consul-server-0:/tmp/restore.snap
kubectl exec -n ${NAMESPACE} consul-server-0 -- consul snapshot restore /tmp/restore.snap

# Scale up remaining servers
echo "Scaling up remaining servers..."
kubectl scale statefulset/consul-server -n ${NAMESPACE} --replicas=3

# Wait for cluster to stabilize
echo "Waiting for cluster to stabilize..."
sleep 30

# Verify restore
echo "Verifying restore..."
kubectl exec -n ${NAMESPACE} consul-server-0 -- consul members

echo "Restore completed successfully!"
