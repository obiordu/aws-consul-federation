package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestEKSConfiguration(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/eks",
		Vars: map[string]interface{}{
			"environment": "test",
			"region":     "us-west-2",
			"vpc_id":     "vpc-dummy-id", // Will be replaced with actual VPC ID
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test EKS Cluster
	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	cluster := aws.GetEksCluster(t, "us-west-2", clusterName)
	assert.Equal(t, "ACTIVE", cluster.Status)

	// Test Node Groups
	nodeGroups := aws.GetEksNodeGroups(t, "us-west-2", clusterName)
	assert.Greater(t, len(nodeGroups), 0)
	for _, ng := range nodeGroups {
		assert.Equal(t, "ACTIVE", ng.Status)
	}

	// Test Kubernetes Configuration
	kubeconfig := terraform.Output(t, terraformOptions, "kubeconfig")
	options := k8s.NewKubectlOptionsWithConfigContents("", []byte(kubeconfig))

	// Test Kubernetes API Access
	pods, err := k8s.ListPodsE(t, options, "kube-system")
	require.NoError(t, err)
	assert.Greater(t, len(pods), 0)

	// Test IAM Roles
	iamRoles := aws.GetIamRoles(t, nil)
	clusterRole := terraform.Output(t, terraformOptions, "cluster_role_name")
	nodeRole := terraform.Output(t, terraformOptions, "node_role_name")
	
	roleFound := false
	for _, role := range iamRoles {
		if role.RoleName == clusterRole || role.RoleName == nodeRole {
			roleFound = true
			break
		}
	}
	assert.True(t, roleFound)
}
