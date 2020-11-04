# Recipe files schema

Recipe files are written in YAML and adhere to the specifications outlined below.

## Filename format

Recipe definition files are placed under `recipes/org/<integration_name>` and should have the following format:

> Note: TBD on final format
`integrationName_<variant>.yml`

For example:

`recipes/newrelic/infra-agent/infra_amazonlinux2.yml`

## Schema definition

```yaml
metadata:
  #TBD:
  # id:
  #   - node
  #   - nodejs

  # Integration/Product name
  # Example: Infrastructure Agent Linux Installer
  name: string, required

  # Example: New Relic install recipe for the Infrastructure agent
  description: string, required

  # Example: https://github.com/newrelic/infrastructure-agent
  repository: string, required

  # Still TBD
  # Some variable/indicator for where you're trying to install this that isn't necessarily where you're running the newrelic-cli from
  # See http://download.newrelic.com/infrastructure_agent/ for possible permutations
  variant: object, required
    os: list (string), optional                  # Windows / linux distro. Ex: windows, ubuntu-X.X.X, amazonLinux-X.X.X, CentOS-X.X.X, sles-X.X.X
    arch: list (string), optional                # Processor architecture type. Ex: 386, amd64, arm, s390x, etc.
    target_environment: list (string), optional  # Options - vm, docker, kubernetes, serverless/lambda, prometheus-exporter etc.

  # keyword convention for dealing with search terms that could land someone on this instrumentation project
  # Example:
    # - Node
    # - Node.js
    # - Microsoft Azure Web Apps
  keywords: list, required

  # Examine Infrastructure events for correlated data
  # Non-empty list of process definitions. Required.
  process_match: list, required
    - /infra/

  # Examine Metrics, Events, and Logging for correlated data
  # Used by the UI to determine if you've successfully configured and are ingesting data
  melt_match: object, required
    events: list, optional
      # Pattern to match melt data type
      # example: /SystemSample/
      - pattern: list, required
    metrics: list, optional
      # Pattern to match melt data type
      # example: /system.cpu.usage/
      - pattern: list, required
    logging: list, optional
      # Pattern to match melt data type
      # example: /http/
      pattern: list, required
      # List of files to look for in the UI
      files: list, optional
        - /var\/log\/system.log

# go-task yaml definition
# This spec - https://github.com/go-task/task
install: string, required

  version: '3'

  env:
    NR_LICENSE_KEY: '{{.NR_LICENSE_KEY}}'

  variables:
    - FOO_VAR: foo-value

  tasks:
      install:
        cmds:
          - task: setup_nr_profile
          - task: install_infra

      setup_nr_profile:
        cmds:
          - echo "Setting up NR Profile"

      install_infra:
        cmds:
          - echo "Installing the Infrastructure agent"
          - curl -L https://raw.githubusercontent.com/fryckbos/infra-install/master/install.sh {{.NR_LICENSE_KEY}} | sh
        silent: true

```
