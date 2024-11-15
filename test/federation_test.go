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

func TestConsulFederation(t *testing.T) {
	t.Parallel()

	workingDir := "../"
	primaryRegion := "us-west-2"
	secondaryRegion := "us-east-1"

	// Deploy infrastructure
	test_structure.RunTestStage(t, "setup", func() {
		terraformOptions := &terraform.Options{
			TerraformDir: workingDir,
			Vars: map[string]interface{}{
				"environment": fmt.Sprintf("test-%s", random.UniqueId()),
				"regions": map[string]string{
					"primary":   primaryRegion,
					"secondary": secondaryRegion,
				},
			},
		}

		terraform.InitAndApply(t, terraformOptions)
		test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)
	})

	// Clean up resources
	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		terraform.Destroy(t, terraformOptions)
	})

	// Test federation connectivity
	test_structure.RunTestStage(t, "validate_federation", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)

		// Get kubeconfig for both clusters
		primaryKubeconfig := terraform.Output(t, terraformOptions, "primary_kubeconfig")
		secondaryKubeconfig := terraform.Output(t, terraformOptions, "secondary_kubeconfig")

		// Create test namespace
		namespace := fmt.Sprintf("test-%s", random.UniqueId())
		k8s.CreateNamespace(t, primaryKubeconfig, namespace)
		k8s.CreateNamespace(t, secondaryKubeconfig, namespace)

		// Deploy test services
		deployTestService(t, primaryKubeconfig, namespace, "primary-service")
		deployTestService(t, secondaryKubeconfig, namespace, "secondary-service")

		// Wait for services to be healthy
		time.Sleep(30 * time.Second)

		// Verify cross-DC service discovery
		validateServiceDiscovery(t, primaryKubeconfig, namespace, "secondary-service")
		validateServiceDiscovery(t, secondaryKubeconfig, namespace, "primary-service")
	})

	// Test failover
	test_structure.RunTestStage(t, "validate_failover", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		primaryKubeconfig := terraform.Output(t, terraformOptions, "primary_kubeconfig")

		// Scale down primary Consul servers
		k8s.RunKubectl(t, primaryKubeconfig, "scale", "deployment", "consul-server", "--replicas=0", "-n", "consul")

		// Wait for failover
		time.Sleep(60 * time.Second)

		// Verify DNS failover
		dnsOutput := terraform.Output(t, terraformOptions, "consul_endpoint")
		assert.Contains(t, dnsOutput, secondaryRegion)
	})

	// Test backup and restore
	test_structure.RunTestStage(t, "validate_backup_restore", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		primaryKubeconfig := terraform.Output(t, terraformOptions, "primary_kubeconfig")

		// Create test data
		namespace := fmt.Sprintf("test-%s", random.UniqueId())
		k8s.CreateNamespace(t, primaryKubeconfig, namespace)
		deployTestService(t, primaryKubeconfig, namespace, "backup-test-service")

		// Trigger backup
		backupOutput := k8s.RunKubectl(t, primaryKubeconfig, "exec", "consul-server-0", "-n", "consul", "--", "consul", "snapshot", "save", "backup.snap")
		assert.Contains(t, backupOutput, "Saved snapshot to backup.snap")

		// Delete test data
		k8s.DeleteNamespace(t, primaryKubeconfig, namespace)

		// Restore backup
		restoreOutput := k8s.RunKubectl(t, primaryKubeconfig, "exec", "consul-server-0", "-n", "consul", "--", "consul", "snapshot", "restore", "backup.snap")
		assert.Contains(t, restoreOutput, "Restored snapshot")

		// Verify restored data
		services := k8s.RunKubectl(t, primaryKubeconfig, "get", "services", "-n", namespace)
		assert.Contains(t, services, "backup-test-service")
	})
}

func deployTestService(t *testing.T, kubeconfig, namespace, name string) {
	k8s.RunKubectl(t, kubeconfig, "create", "deployment", name,
		"--image=nginx",
		"--port=80",
		"-n", namespace)
	k8s.RunKubectl(t, kubeconfig, "expose", "deployment", name,
		"--port=80",
		"-n", namespace)
}

func validateServiceDiscovery(t *testing.T, kubeconfig, namespace, serviceName string) {
	// Deploy debug pod
	debugPod := fmt.Sprintf("debug-%s", random.UniqueId())
	k8s.RunKubectl(t, kubeconfig, "run", debugPod,
		"--image=curlimages/curl",
		"--command", "--",
		"sleep", "3600",
		"-n", namespace)

	// Wait for pod to be ready
	k8s.WaitUntilPodAvailable(t, kubeconfig, debugPod, namespace, 10, 3*time.Second)

	// Test service discovery
	output := k8s.RunKubectl(t, kubeconfig, "exec", debugPod,
		"-n", namespace, "--",
		"curl", "-s", fmt.Sprintf("http://%s.service.consul", serviceName))

	assert.NotEmpty(t, output, "Service discovery failed")
}
