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

func TestConsulSecurity(t *testing.T) {
	t.Parallel()

	workingDir := "../"

	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	primaryKubeconfig := terraform.Output(t, terraformOptions, "primary_kubeconfig")

	// Test TLS Configuration
	t.Run("TLS_Configuration", func(t *testing.T) {
		// Verify TLS is enabled
		output := k8s.RunKubectl(t, primaryKubeconfig, "get", "configmap", "consul-server-config", "-n", "consul", "-o", "yaml")
		assert.Contains(t, output, "verify_incoming: true")
		assert.Contains(t, output, "verify_outgoing: true")
		
		// Test TLS Certificate Validity
		certOutput := k8s.RunKubectl(t, primaryKubeconfig, "exec", "consul-server-0", "-n", "consul", "--", 
			"consul", "tls", "verify", "-server")
		assert.Contains(t, certOutput, "Valid")
	})

	// Test ACL System
	t.Run("ACL_System", func(t *testing.T) {
		// Verify ACL system is enabled
		output := k8s.RunKubectl(t, primaryKubeconfig, "get", "configmap", "consul-server-config", "-n", "consul", "-o", "yaml")
		assert.Contains(t, output, "acl { enabled = true }")

		// Test ACL Token Creation and Policy
		tokenName := fmt.Sprintf("test-token-%s", random.UniqueId())
		createTokenOutput := k8s.RunKubectl(t, primaryKubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
			"consul", "acl", "token", "create", "-description", tokenName, "-policy-name", "readonly")
		assert.Contains(t, createTokenOutput, "SecretID")
	})

	// Test Network Policies
	t.Run("Network_Policies", func(t *testing.T) {
		namespace := fmt.Sprintf("test-%s", random.UniqueId())
		k8s.CreateNamespace(t, primaryKubeconfig, namespace)

		// Deploy test pods
		deployTestService(t, primaryKubeconfig, namespace, "secure-service")
		deployTestService(t, primaryKubeconfig, namespace, "unauthorized-service")

		// Apply network policy
		applyNetworkPolicy(t, primaryKubeconfig, namespace)

		// Test network policy enforcement
		time.Sleep(10 * time.Second)
		
		// Authorized access should succeed
		authorizedOutput := k8s.RunKubectl(t, primaryKubeconfig, "exec", "secure-service", "-n", namespace, "--",
			"curl", "-s", "http://consul-server.consul:8500/v1/status/leader")
		assert.NotEmpty(t, authorizedOutput)

		// Unauthorized access should fail
		unauthorizedOutput := k8s.RunKubectl(t, primaryKubeconfig, "exec", "unauthorized-service", "-n", namespace, "--",
			"curl", "-s", "http://consul-server.consul:8500/v1/status/leader")
		assert.Empty(t, unauthorizedOutput)
	})

	// Test Encryption
	t.Run("Encryption", func(t *testing.T) {
		// Verify gossip encryption is enabled
		output := k8s.RunKubectl(t, primaryKubeconfig, "get", "configmap", "consul-server-config", "-n", "consul", "-o", "yaml")
		assert.Contains(t, output, "encrypt = ")

		// Test encrypted gossip communication
		debugOutput := k8s.RunKubectl(t, primaryKubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
			"consul", "monitor", "-log-level", "debug")
		assert.Contains(t, debugOutput, "encrypted gossip")
	})

	// Test IAM Integration
	t.Run("IAM_Integration", func(t *testing.T) {
		// Verify service account annotations
		output := k8s.RunKubectl(t, primaryKubeconfig, "get", "serviceaccount", "consul-server", "-n", "consul", "-o", "yaml")
		assert.Contains(t, output, "eks.amazonaws.com/role-arn")

		// Test AWS API access
		testOutput := k8s.RunKubectl(t, primaryKubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
			"aws", "sts", "get-caller-identity")
		assert.Contains(t, testOutput, "Arn")
	})
}

func applyNetworkPolicy(t *testing.T, kubeconfig, namespace string) {
	policy := fmt.Sprintf(`
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: consul-access
  namespace: %s
spec:
  podSelector:
    matchLabels:
      app: secure-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: consul
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: consul
`, namespace)

	k8s.KubectlApplyFromString(t, kubeconfig, policy)
}
