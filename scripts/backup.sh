#!/bin/bash
set -e

# Configuration
BACKUP_DIR="/tmp/consul-backup"
RETENTION_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Function to take Consul snapshot
take_snapshot() {
    local datacenter=$1
    local endpoint=$2
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="${BACKUP_DIR}/consul-${datacenter}-${timestamp}.snap"

    echo "Taking snapshot of ${datacenter} datacenter..."
    mkdir -p "${BACKUP_DIR}"
    
    # Take snapshot using Consul API
    if curl -s -o "${backup_file}" "${endpoint}/v1/snapshot"; then
        echo -e "${GREEN}✓ Snapshot created: ${backup_file}${NC}"
        echo "${backup_file}"
    else
        echo -e "${RED}✗ Failed to create snapshot for ${datacenter}${NC}"
        return 1
    fi
}

# Function to upload backup to S3
upload_to_s3() {
    local backup_file=$1
    local bucket=$2
    local filename=$(basename "${backup_file}")

    echo "Uploading ${filename} to S3..."
    if aws s3 cp "${backup_file}" "s3://${bucket}/${filename}"; then
        echo -e "${GREEN}✓ Backup uploaded to S3: ${bucket}/${filename}${NC}"
    else
        echo -e "${RED}✗ Failed to upload backup to S3${NC}"
        return 1
    fi
}

# Function to clean old backups
cleanup_old_backups() {
    local bucket=$1
    
    echo "Cleaning up old backups..."
    
    # Delete local backups older than RETENTION_DAYS
    find "${BACKUP_DIR}" -type f -mtime +${RETENTION_DAYS} -delete
    
    # Delete old S3 backups
    aws s3 ls "s3://${bucket}" | while read -r line; do
        createDate=$(echo "${line}" | awk {'print $1" "$2'})
        createDate=$(date -d "${createDate}" +%s)
        olderThan=$(date -d "${RETENTION_DAYS} days ago" +%s)
        if [[ ${createDate} -lt ${olderThan} ]]; then
            fileName=$(echo "${line}" | awk {'print $4'})
            if aws s3 rm "s3://${bucket}/${fileName}"; then
                echo "Deleted old backup: ${fileName}"
            fi
        fi
    done
}

# Main execution
main() {
    # Check required environment variables
    if [ -z "$PRIMARY_CONSUL_ADDR" ] || [ -z "$SECONDARY_CONSUL_ADDR" ] || [ -z "$BACKUP_BUCKET" ]; then
        echo -e "${RED}Error: Required environment variables not set${NC}"
        echo "Required: PRIMARY_CONSUL_ADDR, SECONDARY_CONSUL_ADDR, BACKUP_BUCKET"
        exit 1
    }

    # Take snapshots
    primary_backup=$(take_snapshot "primary" "${PRIMARY_CONSUL_ADDR}") || exit 1
    secondary_backup=$(take_snapshot "secondary" "${SECONDARY_CONSUL_ADDR}") || exit 1

    # Upload to S3
    upload_to_s3 "${primary_backup}" "${BACKUP_BUCKET}" || exit 1
    upload_to_s3 "${secondary_backup}" "${BACKUP_BUCKET}" || exit 1

    # Cleanup old backups
    cleanup_old_backups "${BACKUP_BUCKET}"

    echo -e "\n${GREEN}Backup process completed successfully!${NC}"
}

main "$@"
