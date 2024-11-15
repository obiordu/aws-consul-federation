module github.com/your-org/aws-consul-federation

go 1.20

require (
	github.com/gruntwork-io/terratest v0.43.0
	github.com/stretchr/testify v1.8.4
	github.com/aws/aws-sdk-go-v2 v1.19.0
	github.com/aws/aws-sdk-go-v2/config v1.18.28
	github.com/aws/aws-sdk-go-v2/service/eks v1.28.1
	github.com/hashicorp/consul/api v1.26.1
	k8s.io/client-go v0.28.4
)

// Indirect dependencies
require (
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
