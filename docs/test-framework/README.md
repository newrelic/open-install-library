# Test Framework

Our test framework has been constructed around the use of another project
known as the [Deployer](https://github.com/newrelic/demo-deployer). The Deployer
takes a [test definition file](https://github.com/newrelic/demo-deployer/tree/main/documentation/deploy_config)
(also known as a `deploy config`), and translates that defintion into actions
like provisioning resources/services and executing commands/scripts. You can loosly think
of the deployer as a wrapper around Ansible.

The Deployer:

* Uses a test definition file specifying what's needed to execute and validate a recipe
* Provisions EC2 resources on AWS
* Runs the recipe and validation
* Destroys/cleans up any created resources

We've containerized the Deployer and made it available on
[GitHub Container Registry](https://github.com/orgs/newrelic/packages/container/package/deployer)
to make it easy to use locally and in our GitHub Actions workflows.

>Note: Executing the Deployer locally should be a part of process of creating a new
>recipe - as this is mechanism we've constructed to test and validate recipes.
>Once the recipe and test definition files run successfully, a Pull Request
>should be opened with those changes so we can execute every test definition
>file that is affected by the recipe change.

## Getting Started

Recipes can be tested locally by either using the Deployer, or Terraform (DEPRECATED):

* [Deployer](local/deployer.md)
* [Terraform](local/terraform.md)

## Automated Testing on Pull Request

The [validation](../.github/workflows/validation.yaml) workflow will on every Pull Request. This workflow will:

* Analyze the commits to check for any changes in the `/recipes` directory
* From that list of recipes, determine which test definition files (under `/test/definitions`) contain references to those recipes
* Run _each_ of those test definition files with the Deployer as a separate GitHub Actions job (Note: this provisions and destroys instances on EC2)
* Output the collective success/failure state

## Non-Regression Testing

The [Non Regression Test](../.github/workflows/nonregression.yaml) workflow will on push to main. This workflow:

* Uses the batch operation (optimized for parallel execution) of the Deployer to run _every_ test definition file in `test/defintions`
* Outputs the collective success/failure state
