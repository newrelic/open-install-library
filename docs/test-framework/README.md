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

* [Deployer](./deployer.md)
* [Terraform](./terraform.md)

## Automated Testing on Pull Request

The [validation](../.github/workflows/validation.yaml) workflow will on every Pull Request. This workflow will:

* Run schema validation using our [JSON schema validator](../../validator/README.md)
* Analyze the commits to check for any changes in the `/recipes` directory
* From that list of recipes, determine which test definition files (under `/test/definitions`) contain references to those recipes
* Run _each_ of those test definition files with the Deployer as a separate GitHub Actions job (Note: this provisions and destroys instances on EC2)
* Output the collective success/failure state

## Non-Regression Testing

The [Non Regression Test](../.github/workflows/nonregression.yaml) workflow will on push to main. This workflow:

* Uses the batch operation (optimized for parallel execution) of the Deployer to run _every_ test definition file in `test/defintions`
* Outputs the collective success/failure state

## Test Definition Files

Each recipe should have at least one corresponding [test definition file](https://github.com/newrelic/demo-deployer/tree/main/documentation/deploy_config) that is used for testing with the Deployer. In a simple case like the infra-agent recipe, the test definition file can be executed by a base AMI without requiring any extra software/integration to be installed. However, it's likely that most on host integrations (OHI) will require additional software to be installed/configured in order to test the recipe.

There are two ways we've established for handling this situation:

* Find/create an AMI that already has the needed software/integrations
* Use a base AMI and install the needed software/integration on top using Ansible

### AMI method

The `AMI` method starts by finding an AMI (typically on the marketplace or by googling) that already has the right software installed.

**Example - [Nginx AMI test definition file](https://github.com/newrelic/open-install-library/blob/main/test/definitions/ohi/linux/nginx-linux2-ami.json)**

This test definition file uses an [AMI](https://github.com/newrelic/open-install-library/blob/main/test/definitions/ohi/linux/nginx-linux2-ami.json#L15) that already has nginx installed. It then uses this [Ansible play](https://github.com/newrelic/open-install-library/blob/main/test/deploy/linux/nginx/open-default/roles/configure/tasks/main.yml) to:

1. Configure Nginx with the status endpoint
2. Restart nginx

### Service method

The `Service` method starts with a base AMI for the distro being tested, and installs the needed integration using Ansible.

**Example - [Nginx Service test definition file](https://github.com/newrelic/open-install-library/blob/main/test/definitions/ohi/linux/nginx-linux2-svc.json)**

This test definition file uses the base Amazon Linux 2 AMI and this [Ansible play](https://github.com/newrelic/open-install-library/blob/main/test/deploy/linux/nginx/install/linux2/roles/configure/tasks/main.yml) to:

1. Install nginx using the amaon-linux-extras package
2. Configure the default status endpoint
3. Restart nginx
