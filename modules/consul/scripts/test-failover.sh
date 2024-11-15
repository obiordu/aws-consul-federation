#!/bin/bash
set -e

# Configuration
PRIMARY_REGION="us-west-2"
SECONDARY_REGION="us-east-1"
CONSUL_DOMAIN="consul.${DOMAIN_NAME}"
PRIMARY_UI="consul-ui.${DOMAIN_NAME}"
SECONDARY_UI="consul-ui-east.${DOMAIN_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Starting Consul Failover Test"
echo "============================"

# Function to check Consul health
check_consul_health() {
    local endpoint=$1
    local region=$2
    
    echo -e "${YELLOW}Checking Consul health in $region...${NC}"
    
    # Check Consul UI endpoint
    if curl -s -o /dev/null -w "%{http_code}" "https://$endpoint/v1/status/leader" | grep -q "200"; then
        echo -e "${GREEN}✓ Consul UI is accessible in $region${NC}"
        return 0
    else
        echo -e "${RED}✗ Consul UI is not accessible in $region${NC}"
        return 1
    fi
}

# Function to verify service mesh
verify_service_mesh() {
    local endpoint=$1
    local region=$2
    
    echo -e "${YELLOW}Verifying service mesh in $region...${NC}"
    
    # Get service mesh status
    local status=$(curl -s "https://$endpoint/v1/agent/self" | jq -r '.Config.ConnectEnabled')
    
    if [ "$status" == "true" ]; then
        echo -e "${GREEN}✓ Service mesh is operational in $region${NC}"
        return 0
    else
        echo -e "${RED}✗ Service mesh is not operational in $region${NC}"
        return 1
    fi
}

# Function to simulate region failure
simulate_region_failure() {
    local region=$1
    
    echo -e "${YELLOW}Simulating failure in $region...${NC}"
    
    # Scale down Consul servers
    kubectl --context $region scale statefulset/consul-server --replicas=0 -n consul
    
    echo -e "${YELLOW}Waiting for failover...${NC}"
    sleep 30
}

# Function to recover region
recover_region() {
    local region=$1
    
    echo -e "${YELLOW}Recovering $region...${NC}"
    
    # Scale up Consul servers
    kubectl --context $region scale statefulset/consul-server --replicas=3 -n consul
    
    echo -e "${YELLOW}Waiting for recovery...${NC}"
    sleep 60
}

# Main test sequence
echo "1. Verifying initial state"
check_consul_health $PRIMARY_UI $PRIMARY_REGION
check_consul_health $SECONDARY_UI $SECONDARY_REGION
verify_service_mesh $PRIMARY_UI $PRIMARY_REGION
verify_service_mesh $SECONDARY_UI $SECONDARY_REGION

echo -e "\n2. Testing primary region failure"
simulate_region_failure $PRIMARY_REGION

echo "3. Verifying failover to secondary region"
if check_consul_health $CONSUL_DOMAIN $SECONDARY_REGION; then
    echo -e "${GREEN}✓ Failover successful${NC}"
else
    echo -e "${RED}✗ Failover failed${NC}"
    exit 1
fi

echo -e "\n4. Recovering primary region"
recover_region $PRIMARY_REGION

echo "5. Verifying recovery"
check_consul_health $PRIMARY_UI $PRIMARY_REGION
verify_service_mesh $PRIMARY_UI $PRIMARY_REGION

echo -e "\n6. Testing secondary region failure"
simulate_region_failure $SECONDARY_REGION

echo "7. Verifying primary region operation"
if check_consul_health $CONSUL_DOMAIN $PRIMARY_REGION; then
    echo -e "${GREEN}✓ Primary region operational${NC}"
else
    echo -e "${RED}✗ Primary region check failed${NC}"
    exit 1
fi

echo -e "\n8. Recovering secondary region"
recover_region $SECONDARY_REGION

echo "9. Final health check"
check_consul_health $PRIMARY_UI $PRIMARY_REGION
check_consul_health $SECONDARY_UI $SECONDARY_REGION
verify_service_mesh $PRIMARY_UI $PRIMARY_REGION
verify_service_mesh $SECONDARY_UI $SECONDARY_REGION

echo -e "\n${GREEN}Failover test completed successfully${NC}"
