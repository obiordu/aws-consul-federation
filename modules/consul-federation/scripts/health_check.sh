#!/bin/bash
set -euo pipefail

# Configuration
CONSUL_HTTP_ADDR="${CONSUL_HTTP_ADDR:-http://localhost:8500}"
CONSUL_HTTP_TOKEN="${CONSUL_TOKEN:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
MIN_SERVERS=3
MIN_CLIENTS=2
MIN_MESH_GATEWAYS=2

# Function to send Slack notification
send_slack_notification() {
    local message="$1"
    local color="$2"
    
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{
                \"attachments\": [
                    {
                        \"color\": \"$color\",
                        \"text\": \"$message\",
                        \"title\": \"Consul Health Check Alert\"
                    }
                ]
            }" "$SLACK_WEBHOOK_URL"
    fi
}

# Check Consul server health
echo "Checking Consul server health..."
server_count=$(kubectl -n consul get pods -l app=consul,component=server --field-selector status.phase=Running -o name | wc -l)
if [ "$server_count" -lt "$MIN_SERVERS" ]; then
    message="WARNING: Only $server_count Consul servers running (minimum: $MIN_SERVERS)"
    echo "$message"
    send_slack_notification "$message" "danger"
    exit 1
fi

# Check Consul client health
echo "Checking Consul client health..."
client_count=$(kubectl -n consul get pods -l app=consul,component=client --field-selector status.phase=Running -o name | wc -l)
if [ "$client_count" -lt "$MIN_CLIENTS" ]; then
    message="WARNING: Only $client_count Consul clients running (minimum: $MIN_CLIENTS)"
    echo "$message"
    send_slack_notification "$message" "danger"
    exit 1
fi

# Check mesh gateway health
echo "Checking mesh gateway health..."
gateway_count=$(kubectl -n consul get pods -l app=consul,component=mesh-gateway --field-selector status.phase=Running -o name | wc -l)
if [ "$gateway_count" -lt "$MIN_MESH_GATEWAYS" ]; then
    message="WARNING: Only $gateway_count mesh gateways running (minimum: $MIN_MESH_GATEWAYS)"
    echo "$message"
    send_slack_notification "$message" "danger"
    exit 1
fi

# Check Consul leader election
echo "Checking Consul leader status..."
leader_check=$(curl -s -f -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" "$CONSUL_HTTP_ADDR/v1/status/leader")
if [ -z "$leader_check" ]; then
    message="ERROR: No Consul leader elected"
    echo "$message"
    send_slack_notification "$message" "danger"
    exit 1
fi

# Check cross-datacenter connectivity
echo "Checking cross-datacenter connectivity..."
dc_list=$(curl -s -f -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" "$CONSUL_HTTP_ADDR/v1/catalog/datacenters")
expected_dcs='["primary","secondary"]'
if [ "$dc_list" != "$expected_dcs" ]; then
    message="ERROR: Cross-datacenter connectivity issue. Found DCs: $dc_list"
    echo "$message"
    send_slack_notification "$message" "danger"
    exit 1
fi

# Check ACL system health
echo "Checking ACL system health..."
acl_status=$(curl -s -f -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" "$CONSUL_HTTP_ADDR/v1/acl/replication")
if [ "$(echo "$acl_status" | jq -r '.Enabled')" != "true" ]; then
    message="WARNING: ACL replication is not enabled"
    echo "$message"
    send_slack_notification "$message" "warning"
fi

# Check TLS certificate expiration
echo "Checking TLS certificate expiration..."
cert_expiry=$(curl -s -f -H "X-Consul-Token: $CONSUL_HTTP_TOKEN" "$CONSUL_HTTP_ADDR/v1/connect/ca/roots" | jq -r '.Roots[0].RootCert | split(".")[1]' | base64 -d | jq -r '.exp')
current_time=$(date +%s)
days_until_expiry=$(( (cert_expiry - current_time) / 86400 ))

if [ "$days_until_expiry" -lt 30 ]; then
    message="WARNING: TLS certificate will expire in $days_until_expiry days"
    echo "$message"
    send_slack_notification "$message" "warning"
fi

# Check Prometheus metrics endpoint
echo "Checking Prometheus metrics endpoint..."
metrics_check=$(curl -s -f "http://localhost:9090/-/healthy")
if [ "$?" -ne 0 ]; then
    message="WARNING: Prometheus metrics endpoint is not responding"
    echo "$message"
    send_slack_notification "$message" "warning"
fi

# Check Grafana health
echo "Checking Grafana health..."
grafana_check=$(curl -s -f "http://localhost:3000/api/health")
if [ "$?" -ne 0 ]; then
    message="WARNING: Grafana is not responding"
    echo "$message"
    send_slack_notification "$message" "warning"
fi

echo "Health check completed successfully"
