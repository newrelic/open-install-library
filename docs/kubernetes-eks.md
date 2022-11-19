# Kubernetes EKS testing

This guide describes how to provision an AWS EKS cluster using CloudFormation.

## Pre-requesite

You'll need the following:
* AWS account
* an AWS specific region (us-east-1 for example)

## Manual deployment using demo-deployer and kubectl, eksctl

Using the demo-deployer, run a deployment using the following [deploy config file](../test/manual/definitions/kubernetes/eks-empty.json). Adjust any of the parameter as needed.

Note, eksctl leverages AWS CloudFormation service to deploy an EKS cluster. Ensure you have at least 1 available VPC slot in the region you'll want to deploy, by default AWS allows 5 VPC maximum.

## Deploying SockShop

If desired, you can install a demo application on the cluster using [SockShop](https://github.com/microservices-demo/microservices-demo/tree/master/deploy/kubernetes)
Note, no traffic is generated with this deployment.

```
git clone https://github.com/microservices-demo/microservices-demo.git
kubectl create -f microservices-demo/deploy/kubernetes/complete-demo.yaml 
```
