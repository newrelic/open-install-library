# Supported Installations

## APM

Currently, the following languages are supported by Guided Install:

* PHP Linux
* .NET Windows and Linux
* NodeJS Linux hosted with PM2 only
* Java Linux for Tomcat, JBoss or Jetty. It uses dynamic attach. Supports docker.

The following languages are detected, and not installed at this time:

* Python
* Ruby
* NodeJS beside Linux/PM2
* Java Windows

The following languages are not supported and not detected by Guided Install:
* Golang
* C SDK

## Infrastructure

The installation of the infrastructure agent with Guided Install is supported for Linux, Windows and MacOS.


In addition, the Logging functionality is also supported and installed with the infrastructure agent installation when installing with Guided Install. 
However, the Logging capability through the infrastructure agent is supported on a subset of platform and OS, see the supported documentation at https://docs.newrelic.com/docs/logs/forward-logs/forward-your-logs-using-infrastructure-agent/#requirements

### Docker

Guided Install also supports docker installation. Typically the command should be run on the host to cover all the docker containers running on the host.

### Kubernetes

The installation of the Kubernetes integration, and Pixie, is supported by Guided Install. The installation must be run on either Linux or MacOS.

### On Host Integration (OHI)

Guided Install supports several OHI installations. Those are located under [OHI recipes](./../recipes//newrelic/infrastructure/ohi/)

## Cloud Providers

### AWS

The NewRelic AWS integration can be installed, more info about that feature at https://docs.newrelic.com/docs/infrastructure/amazon-integrations/get-started/introduction-aws-integrations/

The integration requires an AWS role with the proper read-only permissions to get data into NewRelic. The recipe requires:
* The user must be an AWS Administrator
* The installation is run on an AWS EC2 on Linux
* The AWS access and security keys are stored in their typical ~/.aws/credentials directory

If the requirements above are not met, only the detection of AWS is triggered.

### Azure / GCP

Detection only
