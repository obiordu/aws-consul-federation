package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVPCConfiguration(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/vpc",
		Vars: map[string]interface{}{
			"environment": "test",
			"regions": map[string]interface{}{
				"us-west-2": map[string]interface{}{
					"name": "us-west-2",
					"cidr": "10.0.0.0/16",
				},
				"us-east-1": map[string]interface{}{
					"name": "us-east-1",
					"cidr": "10.1.0.0/16",
				},
			},
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test VPC Creation
	for _, region := range []string{"us-west-2", "us-east-1"} {
		vpc := aws.GetVpcById(t, terraform.Output(t, terraformOptions, fmt.Sprintf("%s_vpc_id", region)), region)
		assert.Equal(t, "available", vpc.State)
		assert.True(t, vpc.IsDefault == false)

		// Test Subnets
		subnets := aws.GetSubnetsForVpc(t, vpc.ID, region)
		assert.Greater(t, len(subnets), 0)

		// Test Route Tables
		routeTables := aws.GetRouteTablesForVpc(t, vpc.ID, region)
		assert.Greater(t, len(routeTables), 0)

		// Test Internet Gateway
		igws := aws.GetInternetGatewaysForVpc(t, vpc.ID, region)
		assert.Equal(t, 1, len(igws))
	}

	// Test VPC Peering
	peeringConnections := aws.GetVpcPeeringConnections(t, "us-west-2", nil)
	assert.Greater(t, len(peeringConnections), 0)
	for _, pc := range peeringConnections {
		assert.Equal(t, "active", pc.Status)
	}
}
