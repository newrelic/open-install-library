# Kubernetes EKS testing

This guide describes how to provision an AWS EKS cluster using CloudFormation.

## Pre-requesite

You'll need the following:
* AWS account
* an AWS specific region (us-east-1 for example)
* In your region, create a key pair of type `pem` in the EC2 UI and keep both the name of the file you used, and the private key file store on your local machine
* Ensure your `pem` key file has correct permission by running `sudo chmod 0400 myKeyPair.pem`

## Provision new cluster with CloudFormation

Follow the link https://fwd.aws/6dEQ7 to create a new cloud formation stack which will create the kubernetes cluster in a new VPC

The CloudFormation UI should be prefilled to load this existing template from an S3 URL https://s3.amazonaws.com/aws-quickstart/quickstart-amazon-eks/templates/amazon-eks-entrypoint-new-vpc.template.yaml

* Check the AWS region is the one you selected to use in the top right corner of the UI
* Click Next
* (Optional) Change the Stack name with something you'll recognize later when you'll want to delete the cluster (by deleting the cloud formation stack)
* Then adjust the configuration with the specific values below

### Basic Configuration

* For `Availability Zones` select only 2 zones from the drop down `b` with either `c` or `a`
* In `Allowed external access CIDR` enter `0.0.0.0/0` to not restrict on any IP
* In `SSH key name` enter your key pair file name (from the pre-requesite)

### VPC network configuration

* For `Number of Availability Zones` select `2`

### Amazon EC2 configuration

* In `Provision bastion host` select `Enabled`. You'll use this host later to SSH and perform `kubectl` commands against the created kubernetes cluster

### Default EKS node group configuration

* For `Instance type` select `t3a.small`
* For `Number of nodes` use `4`
* For `Maximum number of nodes` use `5`

### AWS Quick Start configuration

* For `Quick Start S3 bucket Region` enter the same region than what you've selected in the pre-req (us-east-1 for example)

### Next UI screens

Once all previous inputs are entered, click `Next`
On the next UI, you can review most of the parameters. Scroll to the bottom, acknowledge any disclaimers at the begining and click `Create stack`
You'll then see a UI illustrating the status of the stack creation. You can click the refresh icon on the top right of the `Events` tab to see the most recent activities while the stack is been created.

## Template execution

Running the cloud formation template does take some time, maybe an hour, so be patient.

Once completed, navigate to the EC2 UI, and find the bastion host, typically named `EKSBastion`, and copy the public IP.

You can then SSH onto this host using this IP, for example: `ssh -i "myKeyPair.pem" ec2-user@18.219.179.205`

If you need to copy a file to that remove instance, you can use the scp command, for example: `scp -i "myKeyPair.pem" /home/myusername/file.yml ec2-user@18.219.179.205:.`

Once logged in, you can execute `kubectl` commands to access the cluster. Here are a few commands to check the cluster is running.

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

## Deploying SockShop

If desired, you can install a demo application on the cluster using SockShop.
Note, no traffic is generated with this deployment.

```
git clone https://github.com/microservices-demo/microservices-demo.git
cd microservices-demo/deploy/kubernetes
kubectl create namespace sock-shop
kubectl convert -f . | kubectl create -f -
```

## Un-install newrelic instrumentation

Assuming you've deployed newrelic instrumentation using the manifest file, you can un-install the newrelic instrumentation by running the command below (assuming you SSH into the bastion host).

`kubectl delete -f <manifest.yaml>`
