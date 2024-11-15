package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/assert"
)

func TestConsulFederation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../terraform",
		Vars: map[string]interface{}{
			"environment": "test",
			"regions": map[string]interface{}{
				"primary":   "us-west-2",
				"secondary": "us-east-1",
			},
			"consul_version": "1.16.0",
		},
		// Reduce verbosity of Terraform output
		NoColor: true,
		// Fast fail on error
		MaxRetries: 2,
		// Short timeout for faster feedback
		TimeBetweenRetries: 10 * time.Second,
	}

	// Clean up resources when the test is complete
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Basic validation tests
	validateConsulDeployment(t, terraformOptions)
}

func validateConsulDeployment(t *testing.T, terraformOptions *terraform.Options) {
	// Get outputs
	primaryEndpoint := terraform.Output(t, terraformOptions, "primary_consul_ui_endpoint")
	secondaryEndpoint := terraform.Output(t, terraformOptions, "secondary_consul_ui_endpoint")

	// Validate endpoints
	assert.Contains(t, primaryEndpoint, "consul", "Primary Consul endpoint should contain 'consul'")
	assert.Contains(t, secondaryEndpoint, "consul", "Secondary Consul endpoint should contain 'consul'")

	// Get kubeconfig paths
	primaryKubeconfig := terraform.Output(t, terraformOptions, "primary_kubeconfig")
	secondaryKubeconfig := terraform.Output(t, terraformOptions, "secondary_kubeconfig")

	// Validate Consul pods in primary cluster
	validateConsulPods(t, primaryKubeconfig, "consul")
	
	// Validate Consul pods in secondary cluster
	validateConsulPods(t, secondaryKubeconfig, "consul")
}

func validateConsulPods(t *testing.T, kubeconfigPath string, namespace string) {
	options := k8s.NewKubectlOptions("", kubeconfigPath, namespace)

	// Check if Consul server pods are running
	pods := k8s.ListPods(t, options, "app=consul-server")
	assert.Greater(t, len(pods), 0, "Should have at least one Consul server pod")

	// Check if mesh gateway pods are running
	meshPods := k8s.ListPods(t, options, "app=consul-mesh-gateway")
	assert.Greater(t, len(meshPods), 0, "Should have at least one mesh gateway pod")
}
