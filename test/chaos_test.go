package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

func TestChaosEngineering(t *testing.T) {
	t.Parallel()

	workingDir := "../"
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	primaryKubeconfig := terraform.Output(t, terraformOptions, "primary_kubeconfig")
	secondaryKubeconfig := terraform.Output(t, terraformOptions, "secondary_kubeconfig")

	// Test Network Partition
	t.Run("Network_Partition", func(t *testing.T) {
		// Block cross-region traffic
		blockCrossRegionTraffic(t, terraformOptions)
		defer restoreCrossRegionTraffic(t, terraformOptions)

		// Wait for partition to take effect
		time.Sleep(30 * time.Second)

		// Verify services continue in both regions
		validateRegionHealth(t, primaryKubeconfig, "primary")
		validateRegionHealth(t, secondaryKubeconfig, "secondary")

		// Verify automatic recovery after partition heals
		restoreCrossRegionTraffic(t, terraformOptions)
		time.Sleep(60 * time.Second)
		validateCrossRegionCommunication(t, primaryKubeconfig, secondaryKubeconfig)
	})

	// Test Node Failures
	t.Run("Node_Failures", func(t *testing.T) {
		// Simulate node failures in primary region
		k8s.RunKubectl(t, primaryKubeconfig, "drain", "node1", "--ignore-daemonsets", "--delete-emptydir-data")
		defer k8s.RunKubectl(t, primaryKubeconfig, "uncordon", "node1")

		// Wait for pod rescheduling
		time.Sleep(30 * time.Second)

		// Verify service continuity
		validateServiceContinuity(t, primaryKubeconfig)
	})

	// Test Resource Exhaustion
	t.Run("Resource_Exhaustion", func(t *testing.T) {
		namespace := fmt.Sprintf("stress-%s", random.UniqueId())
		k8s.CreateNamespace(t, primaryKubeconfig, namespace)
		defer k8s.DeleteNamespace(t, primaryKubeconfig, namespace)

		// Deploy resource-intensive workload
		deployStressTest(t, primaryKubeconfig, namespace)

		// Verify Consul stability under load
		time.Sleep(60 * time.Second)
		validateConsulStability(t, primaryKubeconfig)
	})

	// Test Leader Election
	t.Run("Leader_Election", func(t *testing.T) {
		// Force leader step down
		k8s.RunKubectl(t, primaryKubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
			"consul", "operator", "raft", "remove-peer")

		// Wait for new leader election
		time.Sleep(30 * time.Second)

		// Verify cluster stability
		validateClusterStability(t, primaryKubeconfig)
	})

	// Test Data Race Conditions
	t.Run("Data_Race_Conditions", func(t *testing.T) {
		// Create test services with concurrent updates
		namespace := fmt.Sprintf("race-%s", random.UniqueId())
		k8s.CreateNamespace(t, primaryKubeconfig, namespace)
		defer k8s.DeleteNamespace(t, primaryKubeconfig, namespace)

		// Launch concurrent service registrations
		for i := 0; i < 10; i++ {
			go deployTestService(t, primaryKubeconfig, namespace, fmt.Sprintf("race-service-%d", i))
		}

		// Wait for operations to complete
		time.Sleep(30 * time.Second)

		// Verify data consistency
		validateDataConsistency(t, primaryKubeconfig, secondaryKubeconfig, namespace)
	})
}

func blockCrossRegionTraffic(t *testing.T, terraformOptions *terraform.Options) {
	// Implement network partition using AWS security groups
	primaryVpcId := terraform.Output(t, terraformOptions, "primary_vpc_id")
	secondaryVpcId := terraform.Output(t, terraformOptions, "secondary_vpc_id")
	
	// Block all traffic between VPCs
	terraform.Apply(t, &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"block_cross_region_traffic": true,
		},
	})
}

func restoreCrossRegionTraffic(t *testing.T, terraformOptions *terraform.Options) {
	terraform.Apply(t, &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"block_cross_region_traffic": false,
		},
	})
}

func validateRegionHealth(t *testing.T, kubeconfig, region string) {
	// Check Consul server health
	output := k8s.RunKubectl(t, kubeconfig, "get", "pods", "-n", "consul", "-l", "component=server")
	assert.Contains(t, output, "Running")

	// Check service discovery
	services := k8s.RunKubectl(t, kubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
		"consul", "catalog", "services")
	assert.NotEmpty(t, services)
}

func validateCrossRegionCommunication(t *testing.T, primary, secondary string) {
	// Deploy test services
	namespace := fmt.Sprintf("test-%s", random.UniqueId())
	k8s.CreateNamespace(t, primary, namespace)
	k8s.CreateNamespace(t, secondary, namespace)

	deployTestService(t, primary, namespace, "primary-service")
	deployTestService(t, secondary, namespace, "secondary-service")

	// Verify cross-region service discovery
	time.Sleep(30 * time.Second)
	validateServiceDiscovery(t, primary, namespace, "secondary-service")
	validateServiceDiscovery(t, secondary, namespace, "primary-service")
}

func validateServiceContinuity(t *testing.T, kubeconfig string) {
	// Check if services are still accessible
	output := k8s.RunKubectl(t, kubeconfig, "get", "pods", "-A", "-o", "wide")
	assert.Contains(t, output, "Running")

	// Verify Consul health
	health := k8s.RunKubectl(t, kubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
		"consul", "operator", "raft", "list-peers")
	assert.Contains(t, health, "leader")
}

func deployStressTest(t *testing.T, kubeconfig, namespace string) {
	// Deploy stress test pod
	k8s.RunKubectl(t, kubeconfig, "run", "stress-test",
		"--image=polinux/stress",
		"--command", "--",
		"/usr/bin/stress", "--cpu", "4", "--io", "2", "--vm", "2", "--vm-bytes", "128M",
		"-n", namespace)
}

func validateConsulStability(t *testing.T, kubeconfig string) {
	// Check Consul metrics
	metrics := k8s.RunKubectl(t, kubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
		"consul", "monitor", "-log-level", "debug")
	
	// Verify no critical errors
	assert.NotContains(t, metrics, "ERROR")
	assert.NotContains(t, metrics, "CRITICAL")
}

func validateClusterStability(t *testing.T, kubeconfig string) {
	// Check Raft stability
	raft := k8s.RunKubectl(t, kubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
		"consul", "operator", "raft", "list-peers")
	assert.Contains(t, raft, "leader")

	// Check service health
	health := k8s.RunKubectl(t, kubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
		"consul", "members", "-status=alive")
	assert.NotEmpty(t, health)
}

func validateDataConsistency(t *testing.T, primary, secondary, namespace string) {
	// Get service list from both regions
	primaryServices := k8s.RunKubectl(t, primary, "get", "services", "-n", namespace)
	secondaryServices := k8s.RunKubectl(t, secondary, "get", "services", "-n", namespace)

	// Compare service lists
	assert.Equal(t, primaryServices, secondaryServices, "Service lists should match across regions")

	// Verify service health
	for i := 0; i < 10; i++ {
		serviceName := fmt.Sprintf("race-service-%d", i)
		primaryHealth := k8s.RunKubectl(t, primary, "exec", "consul-server-0", "-n", "consul", "--",
			"consul", "catalog", "service", serviceName)
		secondaryHealth := k8s.RunKubectl(t, secondary, "exec", "consul-server-0", "-n", "consul", "--",
			"consul", "catalog", "service", serviceName)
		
		assert.Equal(t, primaryHealth, secondaryHealth, 
			fmt.Sprintf("Service %s should have consistent state across regions", serviceName))
	}
}
