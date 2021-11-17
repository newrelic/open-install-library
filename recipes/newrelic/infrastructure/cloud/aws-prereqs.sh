#!/bin/bash

# Variables
roleName="NewRelicInfrastructure-Integrations-test"
accountId="" # New Relic account id
licenseKey="" # New Relic license key

if ! command -v aws &> /dev/null ; then
  echo "The aws-cli is required to install this integration..."
  echo "Docs: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi

aws sts get-caller-identity &> /dev/null
while [ $? -eq 255 ] ; do
  echo "There are no credentials configured for the aws-cli, a valid AWS account is required to install this integration..."
  echo "Please create a user and configure your account"
  echo "Docs: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html#id_users_create_console"
  echo

  aws configure

  aws sts get-caller-identity &> /dev/null
done

# Check for permissions using sts here...

getRole=$(aws iam get-role --role-name $roleName 2>&1)
if [ $? -eq 0 ] ; then
  echo "The role ($roleName) already exists... great!"
fi

if [ $? -ne 0 ] ; then
  echo $getRole | grep AccessDenied &> /dev/null
  if [ $? -ne 0 ] ; then
    echo "The iam:GetRole permission is required to install this integration..."
    exit 1
  fi

  echo $getRole | grep NoSuchEntity &> /dev/null
  if [ $? -ne 0 ] ; then
    policy=$(cat <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::754728514883:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "$accountId"
                }
            }
        }
    ]
}
EOT
)

    createRole=$(aws iam create-role --role-name $roleName --assume-role-policy-document file://<(echo $policy) 2>&1)
    if [ $? -ne 0 ] ; then
      echo $createRole | grep AccessDenied &> /dev/null
      if [ $? -ne 0 ] ; then
        echo "The iam:CreateRole permission is required to install this integration..."
        exit 1
      fi
    fi

    echo "Created role ($roleName) with a Trust Relationship policy with New Relic account ($accountId)"
  fi
fi

attachRolePolicy=$(aws iam attach-role-policy --role-name $roleName --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess 2>&1)
if [ $? -ne 0 ] ; then
  echo $attachRolePolicy | grep AccessDenied &> /dev/null
  if [ $? -ne 0 ] ; then
    echo "The iam:AttachRolePolicy permission is required to install this integration..."
    exit 1
  fi
fi

echo "Attached ReadOnlyAccess (AWS managed policy) to role ($roleName)"

policy=$(cat <<-EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "budgets:ViewBudget"
      ],
      "Resource": "*"
    }
  ]
}
EOT
)

putRolePolicy=$(aws iam put-role-policy --role-name $roleName --policy-name NewRelicBudget --policy-document file://<(echo $policy) 2>&1)
if [ $? -ne 0 ] ; then
  echo $putRolePolicy | grep AccessDenied &> /dev/null
  if [ $? -ne 0 ] ; then
    echo "The iam:PutRolePolicy permission is required to install this integration..."
    exit 1
  fi
fi

echo "Attached NewRelicBudget (inline policy) to role ($roleName)"

# Download CloudFormation template
# curl -sLO https://nr-downloads-main.s3.amazonaws.com/cloud_integrations/aws/cloudformation/MetricStreams_CloudFormation.yml

deploy=$(aws cloudformation deploy --template-file MetricStreams_CloudFormation.yml --stack-name NewRelic-Metric-Stream --parameter-overrides NewRelicLicenseKey=$licenseKey --capabilities CAPABILITY_NAMED_IAM 2>&1)
if [ $? -ne 0 ] ; then
  echo $deploy | grep "No changes to deploy. Stack NewRelic-Metric-Stream is up to date" &> /dev/null
  if [ $? -ne 0 ] ; then
    echo "NewRelic-Metric-Stream is already deployed."
    exit 0
  fi

  echo "Something went wrong..."
  exit 1
fi

echo "Done!"
