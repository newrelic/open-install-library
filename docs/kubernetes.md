# Kubernetes testing

For manual or automated testing, we can use a minikube kubernetes cluster.
To test with multi-node cluster see the [Kubernetes EKS testing](./kubernetes-eks.md) documentation.

## Pre-requesite

You'll need the following:
* AWS account
* an AWS specific region (us-east-1 for example)
* In your region, create a key pair of type `pem` in the EC2 UI and keep both the name of the file you used, and the private key file store on your local machine
* Ensure your `pem` key file has correct permission by running `sudo chmod 0400 myKeyPair.pem`
* Create your demo-deployer user config file following this documentation https://github.com/newrelic/demo-deployer/blob/main/documentation/user_config/aws.md . Note, if you'll be running the demo-deployer through docker, you'll want the `secretKeyPath` to be defined with the following path `/mnt/deployer/configs/myKeyPair.pem`


## Provision new minikube cluster using the demo-deployer

The demo-deployer is used to provision a minikube host

```bash
docker pull ghcr.io/newrelic/deployer:latest
docker run -it\
    -v $HOME/configs/:/mnt/deployer/configs/\
    --entrypoint ruby ghcr.io/newrelic/deployer main.rb -c configs/<user config filename>.json -d https://raw.githubusercontent.com/newrelic/open-install-library/main/test/manual/definitions/ohi/linux/k8-minikube-empty.json
```

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
