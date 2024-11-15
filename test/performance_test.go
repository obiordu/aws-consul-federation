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

func TestPerformance(t *testing.T) {
	t.Parallel()

	workingDir := "../"
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	primaryKubeconfig := terraform.Output(t, terraformOptions, "primary_kubeconfig")
	secondaryKubeconfig := terraform.Output(t, terraformOptions, "secondary_kubeconfig")

	// Test Service Registration Performance
	t.Run("Service_Registration_Performance", func(t *testing.T) {
		namespace := fmt.Sprintf("perf-%s", random.UniqueId())
		k8s.CreateNamespace(t, primaryKubeconfig, namespace)
		defer k8s.DeleteNamespace(t, primaryKubeconfig, namespace)

		// Measure time to register multiple services
		start := time.Now()
		for i := 0; i < 100; i++ {
			deployTestService(t, primaryKubeconfig, namespace, fmt.Sprintf("perf-service-%d", i))
		}
		duration := time.Since(start)

		// Assert registration time is within acceptable limits
		assert.Less(t, duration.Seconds(), 300.0, "Service registration took too long")

		// Verify all services are healthy
		time.Sleep(30 * time.Second)
		services := k8s.RunKubectl(t, primaryKubeconfig, "get", "services", "-n", namespace)
		for i := 0; i < 100; i++ {
			assert.Contains(t, services, fmt.Sprintf("perf-service-%d", i))
		}
	})

	// Test Cross-Region Latency
	t.Run("Cross_Region_Latency", func(t *testing.T) {
		namespace := fmt.Sprintf("latency-%s", random.UniqueId())
		k8s.CreateNamespace(t, primaryKubeconfig, namespace)
		k8s.CreateNamespace(t, secondaryKubeconfig, namespace)
		defer func() {
			k8s.DeleteNamespace(t, primaryKubeconfig, namespace)
			k8s.DeleteNamespace(t, secondaryKubeconfig, namespace)
		}()

		// Deploy test services
		deployTestService(t, primaryKubeconfig, namespace, "primary-service")
		deployTestService(t, secondaryKubeconfig, namespace, "secondary-service")

		// Measure cross-region request latency
		start := time.Now()
		for i := 0; i < 100; i++ {
			validateServiceDiscovery(t, primaryKubeconfig, namespace, "secondary-service")
		}
		duration := time.Since(start)
		avgLatency := duration.Milliseconds() / 100

		// Assert average latency is within acceptable range
		assert.Less(t, avgLatency, int64(1000), "Cross-region latency too high")
	})

	// Test Concurrent Connections
	t.Run("Concurrent_Connections", func(t *testing.T) {
		namespace := fmt.Sprintf("conn-%s", random.UniqueId())
		k8s.CreateNamespace(t, primaryKubeconfig, namespace)
		defer k8s.DeleteNamespace(t, primaryKubeconfig, namespace)

		// Deploy connection test service
		deployConnectionTestService(t, primaryKubeconfig, namespace)

		// Generate concurrent connections
		start := time.Now()
		for i := 0; i < 1000; i++ {
			go makeServiceRequest(t, primaryKubeconfig, namespace)
		}
		duration := time.Since(start)

		// Verify connection handling
		metrics := getConsulMetrics(t, primaryKubeconfig)
		assert.Less(t, duration.Seconds(), 60.0, "Connection handling took too long")
		assert.NotContains(t, metrics, "connection_errors")
	})

	// Test Memory Usage
	t.Run("Memory_Usage", func(t *testing.T) {
		// Get initial memory usage
		initialMemory := getConsulMemoryUsage(t, primaryKubeconfig)

		// Generate load
		namespace := fmt.Sprintf("mem-%s", random.UniqueId())
		k8s.CreateNamespace(t, primaryKubeconfig, namespace)
		defer k8s.DeleteNamespace(t, primaryKubeconfig, namespace)

		for i := 0; i < 1000; i++ {
			deployTestService(t, primaryKubeconfig, namespace, fmt.Sprintf("mem-service-%d", i))
		}

		// Wait for services to register
		time.Sleep(60 * time.Second)

		// Get final memory usage
		finalMemory := getConsulMemoryUsage(t, primaryKubeconfig)

		// Assert memory growth is within limits
		memoryGrowth := finalMemory - initialMemory
		assert.Less(t, memoryGrowth, float64(1000), "Memory growth too high")
	})

	// Test Service Mesh Performance
	t.Run("Service_Mesh_Performance", func(t *testing.T) {
		namespace := fmt.Sprintf("mesh-%s", random.UniqueId())
		k8s.CreateNamespace(t, primaryKubeconfig, namespace)
		defer k8s.DeleteNamespace(t, primaryKubeconfig, namespace)

		// Deploy mesh-enabled services
		deployMeshService(t, primaryKubeconfig, namespace, "frontend")
		deployMeshService(t, primaryKubeconfig, namespace, "backend")

		// Measure service mesh latency
		start := time.Now()
		for i := 0; i < 100; i++ {
			validateMeshCommunication(t, primaryKubeconfig, namespace)
		}
		duration := time.Since(start)
		avgLatency := duration.Milliseconds() / 100

		// Assert service mesh overhead is acceptable
		assert.Less(t, avgLatency, int64(100), "Service mesh latency too high")
	})
}

func deployConnectionTestService(t *testing.T, kubeconfig, namespace string) {
	k8s.RunKubectl(t, kubeconfig, "create", "deployment", "conn-test",
		"--image=fortio/fortio",
		"--port=8080",
		"-n", namespace)
	k8s.RunKubectl(t, kubeconfig, "expose", "deployment", "conn-test",
		"--port=8080",
		"-n", namespace)
}

func makeServiceRequest(t *testing.T, kubeconfig, namespace string) {
	k8s.RunKubectl(t, kubeconfig, "exec", "conn-test", "-n", namespace, "--",
		"fortio", "load", "-qps", "100", "-t", "60s", "http://localhost:8080")
}

func getConsulMetrics(t *testing.T, kubeconfig string) string {
	return k8s.RunKubectl(t, kubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
		"curl", "-s", "localhost:8500/v1/agent/metrics")
}

func getConsulMemoryUsage(t *testing.T, kubeconfig string) float64 {
	output := k8s.RunKubectl(t, kubeconfig, "exec", "consul-server-0", "-n", "consul", "--",
		"ps", "aux")
	// Parse memory usage from ps output
	var memoryUsage float64
	fmt.Sscanf(output, "%f", &memoryUsage)
	return memoryUsage
}

func deployMeshService(t *testing.T, kubeconfig, namespace, name string) {
	service := fmt.Sprintf(`
apiVersion: v1
kind: Service
metadata:
  name: %s
  namespace: %s
  annotations:
    consul.hashicorp.com/connect-inject: "true"
spec:
  selector:
    app: %s
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: %s
  namespace: %s
spec:
  replicas: 1
  selector:
    matchLabels:
      app: %s
  template:
    metadata:
      labels:
        app: %s
    spec:
      containers:
      - name: %s
        image: nginx
        ports:
        - containerPort: 8080
`, name, namespace, name, name, namespace, name, name, name)

	k8s.KubectlApplyFromString(t, kubeconfig, service)
}

func validateMeshCommunication(t *testing.T, kubeconfig, namespace string) {
	output := k8s.RunKubectl(t, kubeconfig, "exec", "frontend", "-n", namespace, "--",
		"curl", "-s", "http://backend.service.consul:80")
	assert.NotEmpty(t, output)
}
