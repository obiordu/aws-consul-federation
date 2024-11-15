package test

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/eks"
	"github.com/aws/aws-sdk-go-v2/service/route53"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	primaryRegion   = "us-west-2"
	secondaryRegion = "us-east-1"
	moduleDir       = "../modules/consul"
	testNamespace   = "consul-test"
)

type ConsulMember struct {
	Name    string
	Status  int
	Type    string
	DC      string
	Version string
}

func TestConsulFederation(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: moduleDir,
		Vars: map[string]interface{}{
			"domain_name": "example.com",
			"regions": map[string]interface{}{
				primaryRegion: map[string]interface{}{
					"name": primaryRegion,
				},
				secondaryRegion: map[string]interface{}{
					"name": secondaryRegion,
				},
			},
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Setup test namespace
	setupTestNamespace(t)
	defer cleanupTestNamespace(t)

	// Test Infrastructure
	testInfrastructure(t)

	// Test Consul Installation and Federation
	testConsulDeployment(t)

	// Test Service Mesh Features
	testServiceMesh(t)

	// Test Security Features
	testSecurity(t)

	// Test Monitoring
	testMonitoring(t)

	// Test Disaster Recovery
	testDisasterRecovery(t)
}

func setupTestNamespace(t *testing.T) {
	primaryOptions := k8s.NewKubectlOptions("", "", testNamespace)
	k8s.CreateNamespace(t, primaryOptions, testNamespace)

	secondaryOptions := k8s.NewKubectlOptions("", "", testNamespace)
	k8s.CreateNamespace(t, secondaryOptions, testNamespace)
}

func cleanupTestNamespace(t *testing.T) {
	primaryOptions := k8s.NewKubectlOptions("", "", testNamespace)
	k8s.DeleteNamespace(t, primaryOptions, testNamespace)

	secondaryOptions := k8s.NewKubectlOptions("", "", testNamespace)
	k8s.DeleteNamespace(t, secondaryOptions, testNamespace)
}

func testInfrastructure(t *testing.T) {
	// Test EKS Clusters
	testEKSClusters(t, []string{primaryRegion, secondaryRegion})

	// Test Route53 Configuration
	testRoute53Configuration(t)

	// Test VPC Peering
	testVPCPeering(t)

	// Test Load Balancers
	testLoadBalancers(t)
}

func testConsulDeployment(t *testing.T) {
	primaryOptions := k8s.NewKubectlOptions("", "", "consul")
	secondaryOptions := k8s.NewKubectlOptions("", "", "consul")

	// Test Consul Server Deployment
	testConsulServerDeployment(t, primaryOptions, "primary")
	testConsulServerDeployment(t, secondaryOptions, "secondary")

	// Test Federation Setup
	testConsulFederationSetup(t, primaryOptions, secondaryOptions)

	// Test Service Discovery
	testServiceDiscovery(t, primaryOptions, secondaryOptions)
}

func testConsulServerDeployment(t *testing.T, options *k8s.KubectlOptions, dc string) {
	// Wait for Consul servers
	k8s.WaitUntilNumPodsCreated(t, options, "app=consul-server", 3, 10, 10*time.Second)

	pods := k8s.ListPods(t, options, "app=consul-server")
	for _, pod := range pods {
		k8s.WaitUntilPodAvailable(t, options, pod.Name, 10, 10*time.Second)
	}

	// Verify leader election
	output := k8s.RunKubectl(t, options, "exec", "consul-server-0", "--",
		"consul", "operator", "raft", "list-peers")
	assert.Contains(t, output, "leader")

	// Verify server configuration
	output = k8s.RunKubectl(t, options, "exec", "consul-server-0", "--",
		"consul", "members", "-detailed")
	assert.Contains(t, output, dc)
}

func testConsulFederationSetup(t *testing.T, primary, secondary *k8s.KubectlOptions) {
	// Verify mesh gateways
	k8s.WaitUntilNumPodsCreated(t, primary, "app=mesh-gateway", 2, 10, 10*time.Second)
	k8s.WaitUntilNumPodsCreated(t, secondary, "app=mesh-gateway", 2, 10, 10*time.Second)

	// Verify WAN federation
	output := k8s.RunKubectl(t, primary, "exec", "consul-server-0", "--",
		"consul", "members", "-wan")
	assert.Contains(t, output, primaryRegion)
	assert.Contains(t, output, secondaryRegion)

	// Test cross-DC service resolution
	testCrossDCServiceResolution(t, primary, secondary)
}

func testServiceMesh(t *testing.T) {
	options := k8s.NewKubectlOptions("", "", testNamespace)

	// Deploy test services
	k8s.KubectlApply(t, options, "../test/manifests/test-services.yaml")
	defer k8s.KubectlDelete(t, options, "../test/manifests/test-services.yaml")

	// Test service connection
	testServiceConnection(t, options)

	// Test traffic splitting
	testTrafficSplitting(t, options)

	// Test circuit breaking
	testCircuitBreaking(t, options)

	// Test retry policies
	testRetryPolicies(t, options)
}

func testSecurity(t *testing.T) {
	options := k8s.NewKubectlOptions("", "", "consul")

	// Test TLS enforcement
	testTLSEnforcement(t, options)

	// Test ACL enforcement
	testACLEnforcement(t, options)

	// Test network policies
	testNetworkPolicies(t, options)

	// Test secrets management
	testSecretsManagement(t, options)
}

func testMonitoring(t *testing.T) {
	options := k8s.NewKubectlOptions("", "", "monitoring")

	// Test Prometheus metrics
	testPrometheusMetrics(t, options)

	// Test Grafana dashboards
	testGrafanaDashboards(t, options)

	// Test alerts configuration
	testAlertConfiguration(t, options)
}

func testDisasterRecovery(t *testing.T) {
	// Test backup process
	testBackupProcess(t)

	// Test restore process
	testRestoreProcess(t)

	// Test failover
	testFailover(t)

	// Test recovery
	testRecovery(t)
}

func testBackupProcess(t *testing.T) {
	options := k8s.NewKubectlOptions("", "", "consul")

	// Create test data
	k8s.RunKubectl(t, options, "exec", "consul-server-0", "--",
		"consul", "kv", "put", "test/backup-key", "test-value")

	// Trigger backup
	k8s.RunKubectl(t, options, "create", "job", "--from=cronjob/consul-backup",
		"manual-backup")

	// Verify backup exists
	time.Sleep(30 * time.Second)
	output := k8s.RunKubectl(t, options, "exec", "consul-server-0", "--",
		"aws", "s3", "ls", fmt.Sprintf("s3://consul-backup-%s/", primaryRegion))
	assert.Contains(t, output, "consul-")
}

func testFailover(t *testing.T) {
	primaryOptions := k8s.NewKubectlOptions("", "", "consul")
	secondaryOptions := k8s.NewKubectlOptions("", "", "consul")

	// Scale down primary
	k8s.RunKubectl(t, primaryOptions, "scale", "statefulset/consul-server",
		"--replicas=0")

	// Verify secondary takes over
	time.Sleep(30 * time.Second)
	output := k8s.RunKubectl(t, secondaryOptions, "exec", "consul-server-0", "--",
		"consul", "operator", "raft", "list-peers")
	assert.Contains(t, output, "leader")

	// Test service continuity
	testServiceContinuity(t, secondaryOptions)
}

func testRecovery(t *testing.T) {
	primaryOptions := k8s.NewKubectlOptions("", "", "consul")

	// Scale up primary
	k8s.RunKubectl(t, primaryOptions, "scale", "statefulset/consul-server",
		"--replicas=3")

	// Verify cluster health
	time.Sleep(60 * time.Second)
	output := k8s.RunKubectl(t, primaryOptions, "exec", "consul-server-0", "--",
		"consul", "operator", "raft", "list-peers")
	assert.Contains(t, output, "leader")

	// Verify data consistency
	output = k8s.RunKubectl(t, primaryOptions, "exec", "consul-server-0", "--",
		"consul", "kv", "get", "test/backup-key")
	assert.Contains(t, output, "test-value")
}

func testEKSClusters(t *testing.T, regions []string) {
	for _, region := range regions {
		cfg, err := config.LoadDefaultConfig(context.TODO(),
			config.WithRegion(region),
		)
		require.NoError(t, err)

		client := eks.NewFromConfig(cfg)

		input := &eks.DescribeClusterInput{
			Name: &region,
		}

		result, err := client.DescribeCluster(context.TODO(), input)
		require.NoError(t, err)
		assert.Equal(t, "ACTIVE", string(result.Cluster.Status))
	}
}

func testRoute53Configuration(t *testing.T) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	r53Client := route53.NewFromConfig(cfg)
	hostedZoneInput := &route53.ListHostedZonesByNameInput{}
	hostedZones, err := r53Client.ListHostedZonesByName(context.TODO(), hostedZoneInput)
	require.NoError(t, err)

	// Verify health checks
	healthCheckInput := &route53.ListHealthChecksInput{}
	healthChecks, err := r53Client.ListHealthChecks(context.TODO(), healthCheckInput)
	require.NoError(t, err)
	assert.NotEmpty(t, healthChecks.HealthChecks)

	// Verify DNS records
	for _, zone := range hostedZones.HostedZones {
		recordsInput := &route53.ListResourceRecordSetsInput{
			HostedZoneId: zone.Id,
		}
		records, err := r53Client.ListResourceRecordSets(context.TODO(), recordsInput)
		require.NoError(t, err)
		assert.NotEmpty(t, records.ResourceRecordSets)
	}
}

func testVPCPeering(t *testing.T) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	// Check VPC peering connections in both regions
	for _, region := range []string{primaryRegion, secondaryRegion} {
		cfg, err := config.LoadDefaultConfig(context.TODO(),
			config.WithRegion(region))
		require.NoError(t, err)

		ec2Client := ec2.NewFromConfig(cfg)
		input := &ec2.DescribeVpcPeeringConnectionsInput{}
		result, err := ec2Client.DescribeVpcPeeringConnections(context.TODO(), input)
		require.NoError(t, err)

		// Verify peering connections are active
		for _, vpc := range result.VpcPeeringConnections {
			assert.Equal(t, "active", string(*vpc.Status.Code))
		}
	}
}

func testLoadBalancers(t *testing.T) {
	for _, region := range []string{primaryRegion, secondaryRegion} {
		cfg, err := config.LoadDefaultConfig(context.TODO(),
			config.WithRegion(region))
		require.NoError(t, err)

		elbv2Client := elasticloadbalancingv2.NewFromConfig(cfg)
		input := &elasticloadbalancingv2.DescribeLoadBalancersInput{}
		result, err := elbv2Client.DescribeLoadBalancers(context.TODO(), input)
		require.NoError(t, err)

		// Verify load balancers are active
		for _, lb := range result.LoadBalancers {
			assert.Equal(t, "active", string(lb.State.Code))

			// Check target groups
			tgInput := &elasticloadbalancingv2.DescribeTargetGroupsInput{
				LoadBalancerArn: lb.LoadBalancerArn,
			}
			tgResult, err := elbv2Client.DescribeTargetGroups(context.TODO(), tgInput)
			require.NoError(t, err)
			assert.NotEmpty(t, tgResult.TargetGroups)
		}
	}
}

func testServiceDiscovery(t *testing.T, primary, secondary *k8s.KubectlOptions) {
	// Deploy test service in primary DC
	k8s.KubectlApply(t, primary, "../test/manifests/test-services.yaml")
	defer k8s.KubectlDelete(t, primary, "../test/manifests/test-services.yaml")

	// Wait for service registration
	time.Sleep(30 * time.Second)

	// Check service registration in Consul
	output := k8s.RunKubectl(t, primary, "exec", "consul-server-0", "--",
		"consul", "catalog", "services", "-tags")
	assert.Contains(t, output, "frontend")
	assert.Contains(t, output, "backend")

	// Verify service health
	output = k8s.RunKubectl(t, primary, "exec", "consul-server-0", "--",
		"consul", "health", "state", "passing")
	assert.Contains(t, output, "frontend")
	assert.Contains(t, output, "backend")
}

func testCrossDCServiceResolution(t *testing.T, primary, secondary *k8s.KubectlOptions) {
	// Deploy services in both DCs
	k8s.KubectlApply(t, primary, "../test/manifests/cross-dc-services.yaml")
	k8s.KubectlApply(t, secondary, "../test/manifests/cross-dc-services.yaml")
	defer func() {
		k8s.KubectlDelete(t, primary, "../test/manifests/cross-dc-services.yaml")
		k8s.KubectlDelete(t, secondary, "../test/manifests/cross-dc-services.yaml")
	}()

	// Wait for service registration
	time.Sleep(30 * time.Second)

	// Verify cross-DC service resolution
	output := k8s.RunKubectl(t, primary, "exec", "dc1-service-0", "--",
		"curl", "-s", "http://dc2-service.service.dc2.consul")
	assert.Contains(t, output, "Hello from DC2")
}

func testServiceConnection(t *testing.T, options *k8s.KubectlOptions) {
	// Wait for services to be ready
	k8s.WaitUntilNumPodsCreated(t, options, "app=frontend", 2, 10, 10*time.Second)
	k8s.WaitUntilNumPodsCreated(t, options, "app=backend", 2, 10, 10*time.Second)

	// Test frontend to backend connection
	pods := k8s.ListPods(t, options, "app=frontend")
	output := k8s.RunKubectl(t, options, "exec", pods[0].Name, "--",
		"curl", "-s", "http://localhost:9090")
	assert.Contains(t, output, "Hello from Backend")
}

func testTrafficSplitting(t *testing.T, options *k8s.KubectlOptions) {
	// Deploy v2 of backend service
	k8s.KubectlApply(t, options, "../test/manifests/backend-v2.yaml")
	defer k8s.KubectlDelete(t, options, "../test/manifests/backend-v2.yaml")

	// Update traffic split
	split := `
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceSplitter
metadata:
  name: backend
spec:
  splits:
    - weight: 50
      serviceSubset: v1
    - weight: 50
      serviceSubset: v2
`
	k8s.KubectlApplyFromString(t, options, split)

	// Verify traffic split
	for i := 0; i < 10; i++ {
		output := k8s.RunKubectl(t, options, "exec", "frontend-0", "--",
			"curl", "-s", "http://localhost:9090")
		assert.Contains(t, output, "Hello from")
	}
}

func testCircuitBreaking(t *testing.T, options *k8s.KubectlOptions) {
	// Apply circuit breaker config
	circuitBreaker := `
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceDefaults
metadata:
  name: backend
spec:
  protocol: http
  circuitBreaker:
    thresholds:
      maxConnections: 1
      maxPendingRequests: 1
      maxRequests: 1
`
	k8s.KubectlApplyFromString(t, options, circuitBreaker)

	// Generate load to trigger circuit breaker
	output := k8s.RunKubectl(t, options, "exec", "frontend-0", "--",
		"curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "http://localhost:9090")
	assert.Contains(t, output, "503")
}

func testRetryPolicies(t *testing.T, options *k8s.KubectlOptions) {
	// Apply retry policy
	retryPolicy := `
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceDefaults
metadata:
  name: backend
spec:
  protocol: http
  retryPolicy:
    numRetries: 3
    retryOn:
      - 5xx
`
	k8s.KubectlApplyFromString(t, options, retryPolicy)

	// Test retry behavior
	output := k8s.RunKubectl(t, options, "exec", "frontend-0", "--",
		"curl", "-s", "http://localhost:9090")
	assert.NotContains(t, output, "503")
}

func testTLSEnforcement(t *testing.T, options *k8s.KubectlOptions) {
	// Verify TLS is enforced
	output := k8s.RunKubectl(t, options, "exec", "consul-server-0", "--",
		"curl", "-k", "-v", "https://localhost:8501/v1/agent/members")
	assert.Contains(t, output, "SSL connection")
	assert.Contains(t, output, "TLSv1.2")
}

func testACLEnforcement(t *testing.T, options *k8s.KubectlOptions) {
	// Try accessing without token
	output, err := k8s.RunKubectlAndGetOutputE(t, options, "exec", "consul-server-0", "--",
		"curl", "-s", "http://localhost:8500/v1/agent/members")
	require.Error(t, err)
	assert.Contains(t, output, "Permission denied")

	// Get bootstrap token
	token := k8s.GetSecret(t, options, "consul", "consul-bootstrap-acl-token")
	assert.NotEmpty(t, token)

	// Try with token
	output = k8s.RunKubectl(t, options, "exec", "consul-server-0", "--",
		"curl", "-s", "-H", fmt.Sprintf("X-Consul-Token: %s", token),
		"http://localhost:8500/v1/agent/members")
	assert.NotContains(t, output, "Permission denied")
}

func testNetworkPolicies(t *testing.T, options *k8s.KubectlOptions) {
	// Apply restrictive network policy
	policy := `
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: consul
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
`
	k8s.KubectlApplyFromString(t, options, policy)

	// Verify policy enforcement
	_, err := k8s.RunKubectlAndGetOutputE(t, options, "exec", "-n", "default",
		"test-client", "--", "curl", "-s", "http://consul-server.consul:8500")
	assert.Error(t, err)
}

func testSecretsManagement(t *testing.T, options *k8s.KubectlOptions) {
	// Create test secret
	secret := `
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
type: Opaque
data:
  password: SGVsbG8gV29ybGQh
`
	k8s.KubectlApplyFromString(t, options, secret)

	// Verify secret is encrypted
	output := k8s.RunKubectl(t, options, "get", "secret", "test-secret",
		"-o", "yaml")
	assert.Contains(t, output, "password")
	assert.NotContains(t, output, "Hello World!")
}

func testPrometheusMetrics(t *testing.T, options *k8s.KubectlOptions) {
	// Wait for Prometheus
	k8s.WaitUntilNumPodsCreated(t, options, "app=prometheus", 1, 10, 10*time.Second)

	// Query metrics
	output := k8s.RunKubectl(t, options, "exec", "prometheus-0", "--",
		"curl", "-s", "http://localhost:9090/api/v1/query?query=up")
	assert.Contains(t, output, "success")
}

func testGrafanaDashboards(t *testing.T, options *k8s.KubectlOptions) {
	// Wait for Grafana
	k8s.WaitUntilNumPodsCreated(t, options, "app=grafana", 1, 10, 10*time.Second)

	// Check dashboards
	output := k8s.RunKubectl(t, options, "exec", "grafana-0", "--",
		"curl", "-s", "http://admin:admin@localhost:3000/api/dashboards")
	assert.Contains(t, output, "consul")
}

func testAlertConfiguration(t *testing.T, options *k8s.KubectlOptions) {
	// Check AlertManager configuration
	output := k8s.RunKubectl(t, options, "exec", "alertmanager-0", "--",
		"curl", "-s", "http://localhost:9093/api/v2/status")
	assert.Contains(t, output, "success")

	// Verify alert rules
	output = k8s.RunKubectl(t, options, "exec", "prometheus-0", "--",
		"curl", "-s", "http://localhost:9090/api/v1/rules")
	assert.Contains(t, output, "consul")
}

func testRestoreProcess(t *testing.T) {
	options := k8s.NewKubectlOptions("", "", "consul")

	// Create backup
	k8s.RunKubectl(t, options, "create", "job", "--from=cronjob/consul-backup",
		"pre-restore-backup")
	time.Sleep(30 * time.Second)

	// Scale down Consul
	k8s.RunKubectl(t, options, "scale", "statefulset/consul-server",
		"--replicas=0")

	// Restore from backup
	k8s.RunKubectl(t, options, "create", "job", "--from=cronjob/consul-restore",
		"test-restore")
	time.Sleep(30 * time.Second)

	// Scale up Consul
	k8s.RunKubectl(t, options, "scale", "statefulset/consul-server",
		"--replicas=3")

	// Verify restore
	time.Sleep(60 * time.Second)
	output := k8s.RunKubectl(t, options, "exec", "consul-server-0", "--",
		"consul", "kv", "get", "test/backup-key")
	assert.Contains(t, output, "test-value")
}

func testServiceContinuity(t *testing.T, options *k8s.KubectlOptions) {
	// Deploy test service
	k8s.KubectlApply(t, options, "../test/manifests/test-services.yaml")
	defer k8s.KubectlDelete(t, options, "../test/manifests/test-services.yaml")

	// Get initial service response
	initialOutput := k8s.RunKubectl(t, options, "exec", "frontend-0", "--",
		"curl", "-s", "http://localhost:9090")

	// Scale down backend
	k8s.RunKubectl(t, options, "scale", "deployment/backend", "--replicas=0")
	time.Sleep(30 * time.Second)

	// Scale up backend
	k8s.RunKubectl(t, options, "scale", "deployment/backend", "--replicas=2")
	time.Sleep(30 * time.Second)

	// Verify service response after recovery
	finalOutput := k8s.RunKubectl(t, options, "exec", "frontend-0", "--",
		"curl", "-s", "http://localhost:9090")
	assert.Equal(t, initialOutput, finalOutput)
}
