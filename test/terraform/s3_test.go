package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestS3Configuration(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/s3",
		Vars: map[string]interface{}{
			"environment": "test",
			"regions": map[string]interface{}{
				"us-west-2": map[string]interface{}{
					"name": "us-west-2",
				},
			},
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test critical S3 configurations only
	testCriticalS3Configs(t, terraformOptions)
}

func testCriticalS3Configs(t *testing.T, terraformOptions *terraform.Options) {
	primaryBucketName := terraform.Output(t, terraformOptions, "primary_bucket_name")
	
	// Test encryption
	encryption := aws.GetS3BucketEncryption(t, "us-west-2", primaryBucketName)
	assert.Equal(t, "aws:kms", encryption.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm)

	// Test versioning
	versioning := aws.GetS3BucketVersioning(t, "us-west-2", primaryBucketName)
	assert.Equal(t, "Enabled", versioning)

	// Test public access block
	publicAccessBlock := aws.GetS3BucketPublicAccessBlock(t, "us-west-2", primaryBucketName)
	assert.True(t, publicAccessBlock.BlockPublicAcls)
	assert.True(t, publicAccessBlock.BlockPublicPolicy)
}
