# Recipe files schema

Recipe files are written in YAML and adhere to the specifications outlined below.

## Filename format

Recipe definition files are placed under `recipes/org/<on_host_integration_name>` and should have the following format:

> Note: TBD on final format
`<installTargetOS>.yml`

For example:

`recipes/newrelic/infrastructure/amazonlinux2.yml`
`recipes/newrelic/infrastructure/ohi/nginx/amazonlinux2.yml`

TBD - determine naming scheme when the a given recipe can be distro/os agnostic.

## Schema definition

```yaml

# Unique handle
# Example: infrastructure-agent-linuxinstaller
name: string, required

# Friendly name of the integration
# Example: Infrastructure Agent Linux Installer
displayName: string, required

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
    platform: string (enum), optional         # One of [ amazon, ubuntu, debian, centos, redhat, suse ]
    platformFamily: string (enum), optional   # One of [ debian, rhel, suse, ... ]
    platformVersion: string, optional         # "17.10"
    kernelVersion: string, optional           # version of the OS kernel (if available)
    kernelArch: string, optional              # native cpu architecture queried at runtime, as returned by `uname -m` or empty string in case of error

# keyword convention for dealing with search terms that could land someone on this instrumentation project
# Example:
  # - Node
  # - Node.js
  # - Microsoft Azure Web Apps
keywords: list, required

# CLI runs process detection; this is used to filter recipes that are appropriate for matched processes.
# Non-empty list of process definitions.
processMatch: list, required
  - /infra/
  - /usr/bin/local/node/

# Matches partial list of the Log forwarding parameters
# https://docs.newrelic.com/docs/logs/enable-log-management-new-relic/enable-log-monitoring-new-relic/forward-your-logs-using-infrastructure-agent#parameters
logMatch: list (object), optional  
  - name: string, required
    file: string, optional        # Path to the log file or files. Your file can point to a specific log file or multiple ones by using wildcards applied to names and extensions; for example, /logs/*.log
    attributes: object, optional  # Custom attributes to enrich data
      logtype: string, optional   # key/value pair
    pattern: string, optional     # Regular expression for filtering records. https://docs.newrelic.com/docs/logs/enable-log-management-new-relic/enable-log-monitoring-new-relic/forward-your-logs-using-infrastructure-agent#pattern
    systemd: string, optional     # [LINUX ONLY] Service name. Once the systemd input is activated, log messages are collected from the journald daemon in Linux environments.

# Prompts for input from the user. These variables then become
# available to go-task in the form of {{.VAR_NAME}}
inputVars: list, optional
  - name: string, required      # name of the variable
    prompt: string, optional    # message prompt to present to the user
    secret: boolean, optional   # Indicates a password field. Use true/false (no quotes)
    default: string, optional   # default value for variable

# NRQL the newrelic-cli will use to validate the agent/integration this recipe
# installed is successfully sending data to New Relic
validationNrql: string, optional

# Optional pre-install configuration items.
# Useful for things like including prompt info on dependencies and what vars could be supplied to the CLI to automate this recipe.
# Can be extended in the future for any pre-install hooks we'd want the newrelic-cli to run.
preInstall: object, optional
  prompt: string, optional    # Message/Docs notice to display to the user before running recipe.

# go-task yaml definition
# This spec - https://github.com/go-task/task
install: string, required

  version: '3'

  # Silent mode disables echoing of commands before Task runs it.
  # https://taskfile.dev/#/usage?id=silent-mode
  silent: true
  
  # DO NOT USE: License Key is automatically injected by the newrelic-cli
  # env:
  #   NEW_RELIC_LICENSE_KEY: '{{.NEW_RELIC_LICENSE_KEY}}'

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
        - curl -L https://raw.githubusercontent.com/fryckbos/infra-install/master/install.sh {{.NEW_RELIC_LICENSE_KEY}} | sh
      silent: true

```

## Schema Validator

See [open-install-library/validator](../../validator).
