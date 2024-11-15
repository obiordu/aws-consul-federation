#!/bin/bash
set -euo pipefail

# Configuration
BACKUP_BUCKET="${BACKUP_BUCKET:-consul-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
CONSUL_HTTP_ADDR="${CONSUL_HTTP_ADDR:-http://localhost:8500}"
CONSUL_HTTP_TOKEN="${CONSUL_TOKEN:-}"
BACKUP_PREFIX="consul-backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_PREFIX}-${TIMESTAMP}.snap"

# Ensure AWS credentials are available
if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    echo "ERROR: AWS credentials not found"
    exit 1
fi

# Create backup
echo "Creating Consul snapshot..."
curl -s \
    --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
    --request PUT \
    "$CONSUL_HTTP_ADDR/v1/snapshot" \
    -o "$BACKUP_FILE"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create Consul snapshot"
    exit 1
fi

# Encrypt backup
echo "Encrypting backup..."
gpg --symmetric --batch --yes --passphrase "${GPG_PASSPHRASE:-}" "$BACKUP_FILE"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to encrypt backup"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Upload to S3
echo "Uploading to S3..."
aws s3 cp "${BACKUP_FILE}.gpg" "s3://${BACKUP_BUCKET}/${BACKUP_FILE}.gpg"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to upload backup to S3"
    rm -f "$BACKUP_FILE" "${BACKUP_FILE}.gpg"
    exit 1
fi

# Cleanup old backups locally
rm -f "$BACKUP_FILE" "${BACKUP_FILE}.gpg"

# Cleanup old backups in S3
echo "Cleaning up old backups..."
aws s3 ls "s3://${BACKUP_BUCKET}/" | \
    grep "${BACKUP_PREFIX}" | \
    awk '{print $4}' | \
    while read -r backup; do
        backup_date=$(echo "$backup" | grep -o '[0-9]\{8\}')
        backup_date_sec=$(date -d "${backup_date}" +%s)
        current_date_sec=$(date +%s)
        age_days=$(( (current_date_sec - backup_date_sec) / 86400 ))
        
        if [ "$age_days" -gt "$RETENTION_DAYS" ]; then
            echo "Removing old backup: $backup"
            aws s3 rm "s3://${BACKUP_BUCKET}/$backup"
        fi
    done

echo "Backup complete: ${BACKUP_FILE}.gpg"
