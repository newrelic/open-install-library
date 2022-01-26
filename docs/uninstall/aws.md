# Steps to uninstall the AWS Metric Streams Integration

_Note: the CloudFormation template is deployed per AWS region. Please ensure that you are looking at the correct region in the AWS console._

Unlink your AWS account from New Relic:
- https://one.newrelic.com > Infrastructure > AWS > Unlink this account

Delete the NewRelic-Metric-Stream stack found in CloudFormation:
- https://console.aws.amazon.com/cloudformation/home

Delete the IAM Role:
- https://console.aws.amazon.com/iam/home#/roles/NewRelicInfrastructure-Integrations
