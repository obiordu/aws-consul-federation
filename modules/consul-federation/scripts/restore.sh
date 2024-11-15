#!/bin/bash
set -euo pipefail

# Configuration
BACKUP_BUCKET="${BACKUP_BUCKET:-consul-backups}"
CONSUL_HTTP_ADDR="${CONSUL_HTTP_ADDR:-http://localhost:8500}"
CONSUL_HTTP_TOKEN="${CONSUL_TOKEN:-}"
BACKUP_PREFIX="consul-backup"
RESTORE_DIR="/tmp/consul-restore"

# Ensure required variables are set
if [ -z "${BACKUP_FILE:-}" ]; then
    echo "ERROR: BACKUP_FILE must be specified"
    exit 1
fi

if [ -z "${GPG_PASSPHRASE:-}" ]; then
    echo "ERROR: GPG_PASSPHRASE must be specified"
    exit 1
fi

# Create temporary directory
mkdir -p "$RESTORE_DIR"
cd "$RESTORE_DIR"

# Download backup from S3
echo "Downloading backup from S3..."
aws s3 cp "s3://${BACKUP_BUCKET}/${BACKUP_FILE}" "./${BACKUP_FILE}"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download backup from S3"
    rm -rf "$RESTORE_DIR"
    exit 1
fi

# Decrypt backup
echo "Decrypting backup..."
gpg --decrypt --batch --yes --passphrase "$GPG_PASSPHRASE" "${BACKUP_FILE}" > "${BACKUP_FILE%.gpg}"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to decrypt backup"
    rm -rf "$RESTORE_DIR"
    exit 1
fi

# Verify backup integrity
echo "Verifying backup integrity..."
if ! consul snapshot inspect "${BACKUP_FILE%.gpg}"; then
    echo "ERROR: Backup verification failed"
    rm -rf "$RESTORE_DIR"
    exit 1
fi

# Stop Consul services
echo "Stopping Consul services..."
kubectl -n consul scale deployment/consul-server --replicas=0
kubectl -n consul scale deployment/consul-client --replicas=0

# Wait for services to stop
echo "Waiting for services to stop..."
kubectl -n consul wait --for=delete pod -l app=consul,component=server --timeout=300s
kubectl -n consul wait --for=delete pod -l app=consul,component=client --timeout=300s

# Restore backup
echo "Restoring Consul snapshot..."
curl -s \
    --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
    --data-binary @"${BACKUP_FILE%.gpg}" \
    --request PUT \
    "$CONSUL_HTTP_ADDR/v1/snapshot"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to restore Consul snapshot"
    rm -rf "$RESTORE_DIR"
    exit 1
fi

# Restart Consul services
echo "Restarting Consul services..."
kubectl -n consul scale deployment/consul-server --replicas=3
kubectl -n consul scale deployment/consul-client --replicas=3

# Wait for services to start
echo "Waiting for services to start..."
kubectl -n consul wait --for=condition=ready pod -l app=consul,component=server --timeout=300s
kubectl -n consul wait --for=condition=ready pod -l app=consul,component=client --timeout=300s

# Cleanup
rm -rf "$RESTORE_DIR"

echo "Restore complete"
