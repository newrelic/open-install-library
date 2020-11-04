# Validate integration definitions

The tool in this folder validates integration definition files for all cloud and Prometheus integrations.

More information about integration definition files can be found in [definition files format](../format.md).

## How validation occurs

Validation of the definition files happens in two steps:

1. Schema validation: Checks for structural errors in the files, like missing required properties or invalid values for some of the properties.
2. Linting: Checks duplication of values for entity and metric names (inside a single file).

Validation runs automatically whenever there is a pull request.

If you want to validate definition files manually, for example for a newly created file before opening a pull request, just put the file in the `definitions` folder  and run the validation locally like explained [here](#local-setup).

### schema generation

[schema-v1.json](./schema-v1.json) was generated with the help of [https://jsonschema.net](https://jsonschema.net/home). To update, use [docs/spec.json](../docs/spec.json) and generate a JSON schema definition at [JSONschema.net](https://jsonschema.net/home), then replace the content in [schema-v1.json](./schema-v1.json).

### Local setup

There are two different ways of validating files locally.

You can run it using `npm`:

1. Install [NodeJS](https://nodejs.org/en/).
2. Optionally, install [nvm](https://github.com/nvm-sh/nvm).
3. Clone this repo: `git clone https://github.com/newrelic/nr-integration-definitions`.
4. Run `npm --prefix validator install`.
5. Run `npm --prefix validator check`.

You can also run each of the validation tools independently:

```sh
npm  --prefix validator run validate-schema
npm  --prefix validator run lint
```

If you do not want to install NodeJS, you can use the provided Dockerfile, `Dockerfile.validator`, to validate the definition files.

1. Make sure you have `docker` installed (https://docs.docker.com/get-docker/).
2. Build the image:

    ```sh
    docker build . -f Dockerfile.validator -t newrelic/definitions-validator
    ```

3. Run the container:

    ```sh
    docker run -v $PWD/definitions:/opt/local/newrelic/definitions newrelic/definitions-validator
    ```

The tool expects all integration definition files to be in a folder called `definitions` at the same level of the tool folder: map the local `definitions` folder inside the container.
