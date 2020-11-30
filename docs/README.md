# Open Install Library

A collection of recipies designed to support the automated installation and setup of New Relic products and integrations.

## Getting Started

* [Recipe Spec](./recipe-spec/recipe-spec.md)
* [Testing Framework](./test-framework/README.md)

## Contributing Recipes

Recipes are written in YAML and must adhere to our [recipe spec](./recipe-spec/recipe-spec.md). The basic development workflow is:

* Create the recipe under `recipes/org/<on_host_integration_name>/<installTargetOS>.yml`
* Create a corresponding [test definition file](https://github.com/newrelic/demo-deployer/tree/main/documentation/deploy_config) under `test/definitions/ohi/linux/<installTargetOS>.yml`, as well as any needed ansible plays under `test/deploy`.
* Run the [Deployer locally](test-framework/deployer.md).
* Open a Pull Request with the new recipe and corresponding test definition files

### Common variables

The `newrelic-cli` injects at runtime of a go-task the following variables:

* `{{.NR_LICENSE_KEY}}` populated by the key associated with the profile run with the CLI

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