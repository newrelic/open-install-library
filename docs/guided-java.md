# Guided Install

We’ve made it simple to set up our Java APM using New Relic's Guided Installation flow, so you can instrument java applications and start analyzing your telemetry data in 5 minutes - no instrumentation expertise required.​

## Supported Environments
The guided install will automatically instrument the following app/web servers running on Linux platforms, both on-host and running in Docker containers

- JBoss 7.0 to latest
- JBoss EAP 6.0 to 7.3
- Jetty 7.0.0.M3 to 9.4.x (currently not supported in Docker containers)
- Tomcat 7.0.0 to 9.0.x
- WildFly 8.0.0.Final to latest

The [infrastructure monitoring agent](https://docs.newrelic.com/docs/infrastructure/install-infrastructure-agent/get-started/install-infrastructure-agent/) is required for this feature and is included with this installation


## Installation
- Use Guided Install while on NR1 - Add Data

## Updating previous installations

### Renaming an application
To rename a New Relic application you have previously created, simply re-run the guided installation.  You will be prompted to enter a new application name during installation.  You will need to restart any previously-instrumented applications to start sending telemetry data using the application name.

### Upgrading Java agent
To upgrade to the latest Java agent, simply re-run the guided installation.  The latest Java APM agent will be downloaded to your host.  You will need to restart and previously-instrumented applications to start sending telemetry data using the latest Java agent.

## Uninstall the Java agent

### Disabling java process detection integration
To disable this integration, remove the configuration file located below and restart the infrastruture service
/etc/newrelic-infra/integrations.d/java-dynamic-attach.yml

### Uninstalling 
To remove this integration, delete the following directories and files:
- `/etc/newrelic-infra/integrations.d/java-dynamic-attach.yml`
- `/etc/newrelic-java/`

And remove the following package:
- `sudo apt remove nri-introspector-java`

### Stop reporting telemetry data
Once the integration has been disabled or removed, restart the previously-instrumented application server to stop reporting data to New Relic
