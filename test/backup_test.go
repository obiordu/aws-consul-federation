package test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestConsulBackupAndRestore(t *testing.T) {
	t.Parallel()

	// Generate a random name for resources
	uniqueID := random.UniqueId()
	namespace := fmt.Sprintf("consul-test-%s", uniqueID)

	// Configure Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"environment": fmt.Sprintf("test-%s", uniqueID),
			"namespace":   namespace,
		},
	})

	// Cleanup resources when test completes
	defer terraform.Destroy(t, terraformOptions)

	// Deploy infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Get Kubernetes config
	kubectlOptions := k8s.NewKubectlOptions("", "", namespace)

	// Wait for Consul to be ready
	k8s.WaitUntilPodAvailable(t, kubectlOptions, "consul-server-0", 10, 10*time.Second)

	// Write test data
	testKey := fmt.Sprintf("test/backup-%s", uniqueID)
	testValue := fmt.Sprintf("value-%s", uniqueID)
	writeTestData(t, kubectlOptions, testKey, testValue)

	// Trigger backup
	backupName := triggerBackup(t, kubectlOptions)

	// Verify backup exists in S3
	verifyBackupInS3(t, backupName)

	// Simulate disaster by deleting data
	deleteTestData(t, kubectlOptions, testKey)

	// Restore from backup
	restoreFromBackup(t, kubectlOptions, backupName)

	// Verify restored data
	verifyRestoredData(t, kubectlOptions, testKey, testValue)
}

func writeTestData(t *testing.T, options *k8s.KubectlOptions, key, value string) {
	cmd := fmt.Sprintf("consul kv put %s %s", key, value)
	k8s.RunKubectl(t, options, "exec", "consul-server-0", "--", "sh", "-c", cmd)
}

func triggerBackup(t *testing.T, options *k8s.KubectlOptions) string {
	backupName := fmt.Sprintf("backup-%d.snap", time.Now().Unix())
	cmd := fmt.Sprintf("consul snapshot save %s", backupName)
	k8s.RunKubectl(t, options, "exec", "consul-server-0", "--", "sh", "-c", cmd)
	return backupName
}

func verifyBackupInS3(t *testing.T, backupName string) {
	// Load AWS configuration
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	// Create S3 client
	client := s3.NewFromConfig(cfg)

	// Get backup bucket from environment
	bucket := os.Getenv("BACKUP_BUCKET")
	require.NotEmpty(t, bucket, "BACKUP_BUCKET environment variable must be set")

	// Check if backup exists
	_, err = client.HeadObject(context.TODO(), &s3.HeadObjectInput{
		Bucket: &bucket,
		Key:    &backupName,
	})
	require.NoError(t, err)
}

func deleteTestData(t *testing.T, options *k8s.KubectlOptions, key string) {
	cmd := fmt.Sprintf("consul kv delete %s", key)
	k8s.RunKubectl(t, options, "exec", "consul-server-0", "--", "sh", "-c", cmd)
}

func restoreFromBackup(t *testing.T, options *k8s.KubectlOptions, backupName string) {
	// Scale down Consul
	k8s.RunKubectl(t, options, "scale", "statefulset/consul-server", "--replicas=0")
	time.Sleep(30 * time.Second)

	// Scale up first server
	k8s.RunKubectl(t, options, "scale", "statefulset/consul-server", "--replicas=1")
	k8s.WaitUntilPodAvailable(t, options, "consul-server-0", 10, 10*time.Second)

	// Restore snapshot
	cmd := fmt.Sprintf("consul snapshot restore %s", backupName)
	k8s.RunKubectl(t, options, "exec", "consul-server-0", "--", "sh", "-c", cmd)

	// Scale up remaining servers
	k8s.RunKubectl(t, options, "scale", "statefulset/consul-server", "--replicas=3")
	time.Sleep(30 * time.Second)
}

func verifyRestoredData(t *testing.T, options *k8s.KubectlOptions, key, expectedValue string) {
	cmd := fmt.Sprintf("consul kv get %s", key)
	output := k8s.RunKubectl(t, options, "exec", "consul-server-0", "--", "sh", "-c", cmd)
	assert.Equal(t, expectedValue, output)
}
