package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestConsulHelmDeployment(t *testing.T) {
	t.Parallel()

	// Path to Helm Chart
	helmChartPath := "../../helm/consul"

	// Generate a unique release name
	releaseName := fmt.Sprintf("consul-test-%s", random.UniqueId())
	namespace := "consul-test"

	// Create the namespace
	kubectlOptions := k8s.NewKubectlOptions("", "", namespace)
	k8s.CreateNamespace(t, kubectlOptions, namespace)
	defer k8s.DeleteNamespace(t, kubectlOptions, namespace)

	// Basic options for Helm install
	options := &helm.Options{
		SetValues: map[string]string{
			"global.name":      releaseName,
			"global.datacenter": "dc1",
			"server.replicas":   "1", // Reduced for faster testing
			"connectInject.enabled": "true",
			"meshGateway.enabled":   "true",
			"tls.enabled":           "true",
			"acls.enabled":          "true",
		},
		KubectlOptions: kubectlOptions,
	}

	// Install the Consul chart
	defer helm.Delete(t, options, releaseName, true)
	helm.Install(t, options, helmChartPath, releaseName)

	// Test critical components only
	verifyConsulDeployment(t, kubectlOptions)
	testConsulServer(t, kubectlOptions, releaseName)
	testMeshGateway(t, kubectlOptions, releaseName)
}

func verifyConsulDeployment(t *testing.T, options *k8s.KubectlOptions) {
	// Wait for server pod with shorter timeout
	k8s.WaitUntilNumPodsCreated(t, options,
		"app=consul,component=server", 1, 5, 5*time.Second)

	pods := k8s.ListPods(t, options, "app=consul,component=server")
	k8s.WaitUntilPodAvailable(t, options, pods[0].Name, 5, 5*time.Second)
}

func testConsulServer(t *testing.T, options *k8s.KubectlOptions, releaseName string) {
	// Verify server pod
	serverPods := k8s.ListPods(t, options, "app=consul,component=server")
	require.Equal(t, 1, len(serverPods))

	// Verify basic functionality only
	output := k8s.RunKubectl(t, options, "exec",
		fmt.Sprintf("%s-consul-server-0", releaseName), "--",
		"consul", "members")
	assert.Contains(t, output, "server")
}

func testMeshGateway(t *testing.T, options *k8s.KubectlOptions, releaseName string) {
	// Verify mesh gateway pod with shorter timeout
	k8s.WaitUntilNumPodsCreated(t, options,
		"app=consul,component=mesh-gateway", 1, 5, 5*time.Second)
}

func testConsulClient(t *testing.T, options *k8s.KubectlOptions, releaseName string) {
	// Verify client pods
	clientPods := k8s.ListPods(t, options, "app=consul,component=client")
	assert.Greater(t, len(clientPods), 0)

	// Verify client can connect to server
	output := k8s.RunKubectl(t, options, "exec",
		clientPods[0].Name, "--",
		"consul", "members")
	assert.Contains(t, output, "server")
}

func testHelmUpgrade(t *testing.T, options *helm.Options, chartPath, releaseName string) {
	// Modify values for upgrade
	options.SetValues["server.resources.requests.memory"] = "256Mi"

	// Perform upgrade
	helm.Upgrade(t, options, chartPath, releaseName)

	// Verify upgrade
	verifyConsulDeployment(t, options.KubectlOptions)

	// Verify new values
	serverPods := k8s.ListPods(t, options.KubectlOptions, "app=consul,component=server")
	for _, pod := range serverPods {
		container := pod.Spec.Containers[0]
		memory := container.Resources.Requests.Memory().String()
		assert.Equal(t, "256Mi", memory)
	}
}
