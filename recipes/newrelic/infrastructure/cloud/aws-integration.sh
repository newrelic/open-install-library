#!/bin/bash

# Constants
roleName="NewRelicInfrastructure-Integrations-test" # Role name

# Variables
accountId="" # New Relic account id
apiKey="" # New Relic API key
licenseKey="" # New Relic license key
insightsInsertKey="" # New Relic insights key

accountName=""

if ! command -v aws &> /dev/null; then
    echo "The aws-cli is required to install this integration..."
    echo "Docs: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

callerIdentity=$(aws sts get-caller-identity &> /dev/null)
if [ $? -eq 255 ] ; then
    echo
    echo "There are no credentials configured for the aws-cli, a valid AWS account is required to install this integration..."
    echo "Please create a user and configure your account"
    echo "Docs: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html#id_users_create_console"
    echo

    aws configure

    callerIdentity=$(aws sts get-caller-identity &> /dev/null)
fi

# Account ID for (potentially) calling `aws organizations describe-account` [admin only command]
awsAccountId=$(echo $callerIdentity | sed -n 's/.*\"Account\": \"\([0-9]*\)\".*/\1/p')

# Check for permissions using sts here...?

getRole=$(aws iam get-role --role-name $roleName 2>&1)
if [ $? -eq 0 ] ; then
    echo "The role ($roleName) already exists... great!"
else
    echo $getRole | grep AccessDenied &> /dev/null
    if [ $? -eq 0 ] ; then
        echo "The iam:GetRole permission is required to install this integration..."
        exit 1
    fi

    echo $getRole | grep NoSuchEntity &> /dev/null
    if [ $? -eq 0 ] ; then
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
            if [ $? -eq 0 ] ; then
                echo "The iam:CreateRole permission is required to install this integration..."
                exit 1
            fi
        fi

        echo "Created role ($roleName) with a Trust Relationship policy with New Relic account ($accountId)"
        getRole=$(aws iam get-role --role-name $roleName 2>&1)
    fi
fi

# Role ARN saved for use in NerdGraph mutation
roleArn=$(echo $getRole | sed -n 's/.*\"Arn\": \"\(arn:aws:iam.*\)\".*/\1/p')

attachRolePolicy=$(aws iam attach-role-policy --role-name $roleName --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess 2>&1)
if [ $? -ne 0 ] ; then
    echo $attachRolePolicy | grep AccessDenied &> /dev/null
    if [ $? -eq 0 ] ; then
        echo "The iam:AttachRolePolicy permission is required to install this integration..."
        exit 1
    fi
fi

echo "Attached ReadOnlyAccess (AWS managed policy) to role ($roleName)"

policy=$(cat <<EOT
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
    if [ $? -eq 0 ] ; then
        echo "The iam:PutRolePolicy permission is required to install this integration..."
        exit 1
    fi
fi

echo "Attached NewRelicBudget (inline policy) to role ($roleName)"

# Download CloudFormation template
curl -sLo /tmp/MetricStreams_CloudFormation.yml https://nr-downloads-main.s3.amazonaws.com/cloud_integrations/aws/cloudformation/MetricStreams_CloudFormation.yml

# Fix AWS::AccountId variable (needs single quotes)
sed -ie "s/AWS::AccountId/\'AWS::AccountId\'/g" /tmp/MetricStreams_CloudFormation.yml

printf "\nDeploying CloudFormation template, this may take a few minutes...\n"

set -o pipefail
deploy=$(aws cloudformation deploy --template-file /tmp/MetricStreams_CloudFormation.yml --stack-name NewRelic-Metric-Stream --parameter-overrides NewRelicLicenseKey=$licenseKey --capabilities CAPABILITY_NAMED_IAM 2>&1 | tee /dev/tty)
if [ $? -ne 0 ] ; then

    set +o pipefail

    echo $deploy | grep "No changes" &> /dev/null
    if [ $? -ne 0 ] ; then
        echo
        echo "Something went wrong..."

        rm /tmp/MetricStreams_CloudFormation.yml
        exit 1
    fi
fi

set +o pipefail

echo
echo "Stack deployed!"

rm /tmp/MetricStreams_CloudFormation.yml

mutation=$(cat <<EOT
mutation {
  cloudLinkAccount(
    accountId: $accountId,
    accounts: {
      aws: [{
        name: "$accountName",
        arn: "$roleArn",
        metricCollectionMode: PUSH
      }]
    }
  ) {
    linkedAccounts {
      id
      name
      authLabel
      createdAt
      updatedAt
    }
  }
}
EOT
)

newrelic profile add --profile example --apiKey $apiKey --region US --accountId $accountId --insightsInsertKey $insightsInsertKey --licenseKey $licenseKey &> /dev/null
if [ $? -ne 0 ] ; then
    echo "Unable to add profile..."
    exit 1
fi

newrelic nerdgraph query "$mutation" &> /dev/null
if [ $? -ne 0 ] ; then
    echo "Unable to link AWS and New Relic..."
    exit 1
fi

echo "Your AWS and New Relic accounts are linked!"
