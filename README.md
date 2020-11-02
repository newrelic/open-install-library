[![Community Project header](https://github.com/newrelic/opensource-website/raw/master/src/images/categories/Community_Project.png)](https://opensource.newrelic.com/oss-category/#community-project)

# Open Install Library

A collection of recipies designed to support the automated installation and setup of New Relic products and integrations.

## Mission

Deliver a consistent user experience, open source ecosystem, and platform services that allow any engineer in the world:

- to go from inadequate monitoring
- to complete instrumentation of their environment
- to realizing a win with New Relic

in 5 minutes or less.

## Testing

We utilize Terraform to deploy an EC2 instance for each of the supported Linux distributions.

### Prerequisites

- An AWS account
- Setup the AWS configuration and credentials file as described [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).
- You will likely need to modify [variables.tf](./test/variables.tf) and update `profile`, `public_key`, and `private_key` with your own values. (For instance, the default SSH keypair looks in `~/.ssh/id_rsa.pub` and `~/.ssh/id_rsa`; you need to modify that if your env is different).

### Plan Execution

Once `variables.tf` is set up, execute the following:

1. From the root of this project:

    ```bash
    cd test
    ```

2. Install provider plugins

    ```bash
    terraform init
    ```

3. Review possible changes

    ```bash
    terraform plan
    ```

4. Apply changes

    ```bash
    terraform apply
    ```

5. Cleanup (after you're finished)

    ```bash
    terraform destroy
    ```

### Adding a new distribution

The Terraform variables file (`test/variables.tf`) contains the tested Linux distributions. There are 3 co-indexed lists: `distros`, `amis` and `ami_users`.

In order to add a distribution, add the name of the distribution to the `distros` list, the ami-id to the `amis` list and the username to ssh into the EC2 instance to the `ami_users` list. 

Make sure to add the name, ami-id and username to the same position in the list (for example the last position).

## Support

New Relic hosts and moderates an online forum where customers can interact with New Relic employees as well as other customers to get help and share best practices. Like all official New Relic open source projects, there's a related Community topic in the New Relic Explorers Hub. You can find this project's topic/threads here:

>Add the url for the support thread here

## Contributing
We encourage your contributions to improve [project name]! Keep in mind when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. You only have to sign the CLA one time per project.
If you have any questions, or to execute our corporate CLA, required if your contribution is on behalf of a company,  please drop us an email at opensource@newrelic.com.

## License
Open Install Library is licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.
