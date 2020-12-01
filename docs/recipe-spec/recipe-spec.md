# Recipe files schema

Recipe files are written in YAML and adhere to the specifications outlined below.

## Filename format

Recipe definition files are placed under `recipes/org/<on_host_integration_name>` and should have the following format:

> Note: TBD on final format
`<installTargetOS>.yml`

For example:

`recipes/newrelic/infra-agent/amazonlinux2.yml`
`recipes/newrelic/nginx/amazonlinux2.yml`

TBD - determine naming scheme when the a given recipe can be distro/os agnostic.

## Schema definition

```yaml

# Integration/Product name
# Example: Infrastructure Agent Linux Installer
name: string, required

# Example: New Relic install recipe for the Infrastructure agent
description: string, required

# Example: https://github.com/newrelic/infrastructure-agent
repository: string, required

# Still TBD
# Indicates the target host/runtime/env where user is trying to install (Note: isn't necessarily where you're running the newrelic-cli from)
# See http://download.newrelic.com/infrastructure_agent/ for possible permutations
installTargets: list, required
  - type: string (enum), optional             # One of [ host, application, docker, kubernetes, cloud, serverless ]
    os: string (enum), optional               # linux, darwin, windows
    platform: string (enum), optional         # One of [ amazonlinux, ubuntu, debian, centos, rhel, suse ]
    platformFamily: string (enum), optional   # One of [ debian, rhel, ... ]
    platformVersion: string, optional         # "17.10"
    kernelVersion: string, optional           # version of the OS kernel (if available)
    kernelArch: string, optional              # native cpu architecture queried at runtime, as returned by `uname -m` or empty string in case of error

# keyword convention for dealing with search terms that could land someone on this instrumentation project
# Example:
  # - Node
  # - Node.js
  # - Microsoft Azure Web Apps
keywords: list, required

# Non-empty list of process definitions. Required.
processMatch: list, required
  - /infra/
  - /usr/bin/local/node/

# Examine Metrics, Events, and Logging for correlated data
# Used by the UI to determine if you've successfully configured and are ingesting data
meltMatch: object, required
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

# Prompts for input from the user. These variables then become
# available to go-task in the form of {{.VAR_NAME}}
inputVars: list, optional
  - name: string, required      # name of the variable
    prompt: string, optional    # message prompt to present to the user
    default: string, optional   # default value for variable

# go-task yaml definition
# This spec - https://github.com/go-task/task
install: string, required

  version: '3'

  # Silent mode disables echoing of commands before Task runs it.
  # https://taskfile.dev/#/usage?id=silent-mode
  silent: true
  
  # DO NOT USE: License Key is automatically injected by the newrelic-cli
  # env:
  #   NR_LICENSE_KEY: '{{.NR_LICENSE_KEY}}'

  variables:
    - FOO_VAR: foo-value

  tasks:
    default:  # must have a default task, as the newrelic-cli uses this for an entry point
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

## Schema Validator

See [open-install-library/validator](../validator).
