# Kubernetes EKS testing

This guide describes how to provision an AWS EKS cluster using the [demo-deployer](https://github.com/newrelic/demo-deployer), kubectl, eksctl. 

## Pre-requesite

You'll need the following:
* AWS account
* an AWS specific region (us-east-1 for example) with at least 1 available VPC slot (by default AWS allows a maximum of 5 VPCs)

## Manual deployment using demo-deployer and kubectl, eksctl

Using the demo-deployer, run a deployment using the following [deploy config file](../test/manual/definitions/kubernetes/eks-empty.json). Adjust any of the parameter as needed.

Note, re-running the same deployment is idempotent in the way that subsequent execution will skip over any steps that were previously completed. Likewise for teardown, re-running the same deployment in teardown mode will only terminate the cluster the first time.

### Teardown

Re-run the demo-deployer command in teardown mode by adding `-t` to dispose of any resources associated with the deployment (EKS cluster, EC2 hosts, CloudFormation stacks, VPC)

## Side effects

* an EC2 instance will be created with kubectl and eksctl installed to interact with the K8s cluster.
* eksctl leverages AWS CloudFormation service, with nested stacks.
* eksctl will create a dedicated VPC and roles for the K8s cluster.

## Deploying SockShop

If desired, you can install a demo application on the cluster using [SockShop](https://github.com/microservices-demo/microservices-demo/tree/master/deploy/kubernetes)
Note, no traffic is generated with this deployment.

```
git clone https://github.com/microservices-demo/microservices-demo.git
kubectl create -f microservices-demo/deploy/kubernetes/complete-demo.yaml 
```
