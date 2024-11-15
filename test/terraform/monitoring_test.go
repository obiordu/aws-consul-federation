package test

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMonitoringConfiguration(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/monitoring",
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

	// Test only critical monitoring components
	testPrometheusDeployment(t, terraformOptions)
	testCloudWatchCriticalAlarms(t, terraformOptions)
}

func testPrometheusDeployment(t *testing.T, terraformOptions *terraform.Options) {
	kubectlOptions := k8s.NewKubectlOptions("", "", "monitoring")

	// Verify Prometheus pod with shorter timeout
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions,
		"app=prometheus", 1, 5, 5*time.Second)

	// Test basic Prometheus configuration
	configMap := k8s.GetConfigMap(t, kubectlOptions, "prometheus-config")
	assert.Contains(t, configMap.Data["prometheus.yml"], "consul")
}

func testCloudWatchCriticalAlarms(t *testing.T, terraformOptions *terraform.Options) {
	region := "us-west-2"
	
	// Test only critical Consul health alarm
	consulAlarmName := terraform.Output(t, terraformOptions, region+"_consul_health_alarm_name")
	consulAlarm := aws.GetCloudWatchAlarm(t, region, consulAlarmName)
	assert.Equal(t, "OK", consulAlarm.StateValue)
}
