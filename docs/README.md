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
