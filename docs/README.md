# Open Install Library

A collection of recipies designed to support the automated installation and setup of New Relic products and integrations.

## Getting Started

* [Recipe Spec](./recipe-spec/recipe-spec.md)
* [Testing Framework](./test-framework/README.md)
* [Kubernetes Testing](./kubernetes.md)

## Contributing Recipes

Recipes are written in YAML and must adhere to our [recipe spec](./recipe-spec/recipe-spec.md). The basic development workflow is:

* Create the recipe under `recipes/org/<on_host_integration_name>/<installTargetOS>.yml`
* Create a corresponding [test definition file](https://github.com/newrelic/demo-deployer/tree/main/documentation/deploy_config) under `test/definitions/ohi/linux/<installTargetOS>.yml`, as well as any needed ansible plays under `test/deploy`.
* Run the [Deployer locally](test-framework/deployer.md).
* Open a Pull Request with the new recipe and corresponding test definition files

### Consistency

* MUST include a `default` task for the newrelic-cli to use as an entry point
* Use `silent: true` to omit output at the taskfile level
  
  ```bash
  install:
    version: "3"

    # Silent mode disables echoing of commands before Task runs it.
    # https://taskfile.dev/#/usage?id=silent-mode
    silent: true

    tasks:
      default:
      ...
  ```

* Use `label` to give feedback that the CLI will output
  ```bash
  install:
  version: "3"

  silent: true

  tasks:
    default:
      cmds:
        - task: setup

    setup:
      label: "Installing nginx integration..."
  ```
  
* Accept variables using `inputVars` (see [Common Variables](#configuration-variables))
* Idempotence (see [Idempotence](#idempotence))

### Linux Recipe Package Support

All OHI Linux recipes must support APT (Debian and Ubuntu), Yum (Amazon Linux, CentOS, RHEL), Zypper ( SLES). For testing, at a minimum include tests for these three package managers for Linux recipes.

### Validation Nrql

The [recipe-spec](./recipe-spec/recipe-spec.md) contains `validationNrql` - this can be used to specify NRQL the CLI and test framework will execute to validate the recipe is successfully sending data to New Relic.

Example: Validating Nginx

```bash
validationNrql: "SELECT count(*) from NginxSample where hostname like '{{.HOSTNAME}}' SINCE 10 minutes ago"
```

Note: `{{.HOSTNAME}}` is a Go template variable injected by the newrelic-cli. See [Configuration Variables](#configuration-variables) for more info.

Knowing what Nrql is necessary to write is heavilty dependent on the recipe being written. For help, refer to the [New Relic Docs](https://docs.newrelic.com/) for a given integration for help on which metrics/events/etc. might be useful to query for validating data in NRDB.

### Configuration Variables

All recipes can either run in interactive mode where users are prompted for configuration (when necessary), or in non interactive mode where the configuration is provided already through the CLI.

The `newrelic-cli` injects at runtime of a go-task the following variables:

* `{{.NEW_RELIC_LICENSE_KEY}}` populated by the key associated with the profile run with the CLI
* Input Variables - recipes can use `inputVars` to prompt the user to enter variables needed in the recipe.
  
  ```bash
  # Prompts for input from the user. These variables then become
  # available to go-task in the form of {{.VAR_NAME}}
  inputVars:
    - name: "LOG_FILES"
      prompt: "Which log files would you like to tail?"
      default: "/var/log/messages,/var/log/cloud-init.log,/var/log/secure"
  ```

  More info can be found in the [recipe-spec](./recipe-spec/recipe-spec.md).
* `{{.HOSTNAME}}` - the hostname of the instance the newrelic-cli is run on. This is the same effective output as running the `hostname` command.

### Idempotence

💡 **Recipes should be written in an idempotent manner, as much as that can be achieved.**

For an agent installation, that means re-running the recipe results in the agent being installed the same way as if it were the first time. For example, if vX.X.X of the agent was previously installed using the recipe, re-running the recipe results in the agent now being installed at its latest version.

This section is intended to provide a best practices approach for how to achieve that goal, and will likely improve over time as we write more recipes.

### Write recipes that recreate config files the same way each time

Many recipes will end up writing config files (ex: infra-agent recipes will create `newrelic-infra.yml`). The pattern we're employing to make this happen is:

* Check for the existance of the file and create it if it doesn't exist
* Update the file to include whatever defaults are needed

Example from infra-agent install:

```bash
setup_license:
  cmds:
    - |
      # Check if newrelic-infra.yml exists; if it doesn't, create an empty file
      if [ ! -f /etc/newrelic-infra.yml ]; then
        sudo touch /etc/newrelic-infra.yml;
      fi
    - |
      # Check for a license_key in the file and update it if it exists; otherwise, write a license_key into the file
      grep -q '^license_key' /etc/newrelic-infra.yml && sudo sed -i 's/^license_key.*/license_key: {{.NEW_RELIC_LICENSE_KEY}}/' /etc/newrelic-infra.yml || echo 'license_key: {{.NEW_RELIC_LICENSE_KEY}}' | sudo tee -a /etc/newrelic-infra.yml > /dev/null
```

Another approach might be:

* Check for the existance of the file
* Remove then re-create file
* Write the file with whatever defaults are needed

```bash
setup_license:
  cmds:
    - |
      # Check if newrelic-infra.yml exists; if it does, remove and create a new empty file
      if [ -f /etc/newrelic-infra.yml ]; then
        sudo rm /etc/newrelic-infra.yml;
      fi
      sudo touch /etc/newrelic-infra.yml;
    - |
      # write the license_key into the newrelic-infra.yml config
      echo -e "license_key: {{.NEW_RELIC_LICENSE_KEY}}" | sudo tee -a /etc/newrelic-infra.yml > /dev/null
```

### Installing latest version of a given Agent/OHI should happen automatically

💡 We expect subsequent runs of a recipe to always install the latest version of a given agent/integration/etc.

For example - with Linux installations the Agent/OHI recipes commonly pull from a package manager, and re-running the recipe _should_ automatically pull the latest version and run with that new version.

Example from infra-agent recipe - this will pull latest supported version of newrelic-infra and install it:

```bash
install_infra:
  cmds:
    - sudo curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/7/x86_64/newrelic-infra.repo
    - sudo yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'
    - sudo yum install newrelic-infra -y
    - echo "New Relic infrastructure agent installed"
  silent: true
```

For recipes that install an integration and don't use a package manager, steps should be taken to ensure the latest version of that integration is always installed.
