#!/bin/bash
set -e

# Configuration
MAX_RETRIES=3
RETRY_DELAY=5
TIMEOUT=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Function to check Consul server health
check_consul_health() {
    local endpoint=$1
    local region=$2

    echo "Checking Consul health in $region..."
    
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s -m $TIMEOUT "$endpoint/v1/health/node/$(hostname)" | grep -q "passing"; then
            echo -e "${GREEN}✓ Consul health check passed in $region${NC}"
            return 0
        fi
        
        echo "Attempt $i failed, retrying in $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
    done
    
    echo -e "${RED}✗ Consul health check failed in $region after $MAX_RETRIES attempts${NC}"
    return 1
}

# Function to verify federation status
check_federation() {
    local primary_endpoint=$1
    local secondary_endpoint=$2
    
    echo "Checking federation status..."
    
    # Check primary can see secondary
    if ! curl -s "$primary_endpoint/v1/operator/federation/members" | grep -q "us-east-1"; then
        echo -e "${RED}✗ Primary cluster cannot see secondary datacenter${NC}"
        return 1
    fi
    
    # Check secondary can see primary
    if ! curl -s "$secondary_endpoint/v1/operator/federation/members" | grep -q "us-west-2"; then
        echo -e "${RED}✗ Secondary cluster cannot see primary datacenter${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Federation check passed${NC}"
    return 0
}

# Function to verify backup existence
verify_backup() {
    local bucket=$1
    local date=$(date +%Y-%m-%d)
    
    echo "Verifying Consul backup..."
    
    if aws s3 ls "s3://$bucket/consul-backup-$date" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Backup verification passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Backup verification failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    # Check required environment variables
    if [ -z "$PRIMARY_CONSUL_ADDR" ] || [ -z "$SECONDARY_CONSUL_ADDR" ] || [ -z "$BACKUP_BUCKET" ]; then
        echo -e "${RED}Error: Required environment variables not set${NC}"
        echo "Required variables: PRIMARY_CONSUL_ADDR, SECONDARY_CONSUL_ADDR, BACKUP_BUCKET"
        exit 1
    }

    # Run health checks
    check_consul_health "$PRIMARY_CONSUL_ADDR" "us-west-2" || exit 1
    check_consul_health "$SECONDARY_CONSUL_ADDR" "us-east-1" || exit 1
    check_federation "$PRIMARY_CONSUL_ADDR" "$SECONDARY_CONSUL_ADDR" || exit 1
    verify_backup "$BACKUP_BUCKET" || exit 1

    echo -e "\n${GREEN}All health checks passed successfully!${NC}"
}

main "$@"
