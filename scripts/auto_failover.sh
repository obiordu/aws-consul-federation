#!/bin/bash
set -euo pipefail

# Configuration
PRIMARY_REGION="us-west-2"
SECONDARY_REGION="us-east-1"
DOMAIN_NAME="${DOMAIN_NAME:-consul.domain.com}"
MIN_HEALTHY_SERVERS=2

# Function to check cluster health
check_cluster_health() {
    local region=$1
    local healthy_servers=$(kubectl --context="$region" get pods -n consul -l component=server --field-selector status.phase=Running -o name | wc -l)
    
    if [ "$healthy_servers" -lt "$MIN_HEALTHY_SERVERS" ]; then
        return 1
    fi
    return 0
}

# Function to initiate failover
initiate_failover() {
    echo "Initiating failover to secondary region..."
    
    # Update Route53 health check
    aws route53 update-health-check \
        --health-check-id "$PRIMARY_HEALTH_CHECK_ID" \
        --disabled

    # Scale down primary servers gracefully
    kubectl --context="$PRIMARY_REGION" scale deployment consul-server -n consul --replicas=0

    # Wait for DNS propagation
    echo "Waiting for DNS propagation..."
    sleep 60

    # Verify failover
    local dns_endpoint=$(dig +short "$DOMAIN_NAME")
    if [[ "$dns_endpoint" == *"$SECONDARY_REGION"* ]]; then
        echo "Failover successful"
        return 0
    else
        echo "Failover verification failed"
        return 1
    fi
}

# Function to recover primary
recover_primary() {
    echo "Recovering primary region..."
    
    # Scale up primary servers
    kubectl --context="$PRIMARY_REGION" scale deployment consul-server -n consul --replicas=3

    # Wait for servers to be healthy
    echo "Waiting for primary servers to be healthy..."
    local timeout=300
    local interval=10
    local elapsed=0

    while [ "$elapsed" -lt "$timeout" ]; do
        if check_cluster_health "$PRIMARY_REGION"; then
            break
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    if [ "$elapsed" -ge "$timeout" ]; then
        echo "Primary recovery failed"
        return 1
    fi

    # Re-enable health check
    aws route53 update-health-check \
        --health-check-id "$PRIMARY_HEALTH_CHECK_ID" \
        --no-disabled

    echo "Primary region recovered"
    return 0
}

# Main monitoring loop
while true; do
    if ! check_cluster_health "$PRIMARY_REGION"; then
        echo "Primary region unhealthy"
        
        # Double check after brief delay
        sleep 30
        
        if ! check_cluster_health "$PRIMARY_REGION"; then
            if check_cluster_health "$SECONDARY_REGION"; then
                initiate_failover
            else
                echo "Both regions unhealthy! Manual intervention required!"
                exit 1
            fi
        fi
    elif ! check_cluster_health "$SECONDARY_REGION"; then
        echo "Secondary region unhealthy"
        
        # Attempt recovery if we're already failed over
        local dns_endpoint=$(dig +short "$DOMAIN_NAME")
        if [[ "$dns_endpoint" == *"$SECONDARY_REGION"* ]]; then
            recover_primary
        fi
    fi

    sleep 60
done
