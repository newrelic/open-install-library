# Local Testing - Terraform

We utilize Terraform to deploy an EC2 instance for each of the supported Linux distributions.

## Prerequisites

- An AWS account
- Setup the AWS configuration and credentials file as described [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).
- You will likely need to modify [variables.tf](terraform/variables.tf) and update `profile`, `public_key`, and `private_key` with your own values. (For instance, the default SSH keypair looks in `~/.ssh/id_rsa.pub` and `~/.ssh/id_rsa`; you need to modify that if your env is different).

## Plan Execution

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

## Adding a new distribution

The Terraform variables file [variables.tf](terraform/variables.tf) contains the tested Linux distributions. There are 3 co-indexed lists: `distros`, `amis` and `ami_users`.

In order to add a distribution, add the name of the distribution to the `distros` list, the ami-id to the `amis` list and the username to ssh into the EC2 instance to the `ami_users` list. 

Make sure to add the name, ami-id and username to the same position in the list (for example the last position).
