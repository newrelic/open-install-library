[![New Relic Experimental header](https://github.com/newrelic/opensource-website/raw/master/src/images/categories/Experimental.png)](https://opensource.newrelic.com/oss-category/#new-relic-experimental)

# Open Install Library

A collection of recipies designed to support the automated installation and setup of New Relic products and integrations.

## Mission

Deliver a consistent user experience, open source ecosystem, and platform services that allow any engineer in the world:

- to go from inadequate monitoring
- to complete instrumentation of their environment
- to realizing a win with New Relic

in 5 minutes or less.

## Testing

The testing of recipes is automated, and those are tested on a freshly provisioned environment and re-provisioned on every test run.

Test definitions files are located under the path [test/definitions](test/definitions). Those definitions are used with the [Deployer](https://github.com/newrelic/demo-deployer) to provision all the required resources, run the recipe installation, validate the installation is feeding data into newrelic, and finally teardown all the provisioned resources.

More information about local testing can be found at [Local Testing](test/local/README.md).

## Support

New Relic hosts and moderates an online forum where customers can interact with New Relic employees as well as other customers to get help and share best practices. Like all official New Relic open source projects, there's a related Community topic in the New Relic Explorers Hub. You can find this project's topic/threads here:

>Add the url for the support thread here

## Contributing

We encourage your contributions to improve [project name]! Keep in mind when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. You only have to sign the CLA one time per project.
If you have any questions, or to execute our corporate CLA, required if your contribution is on behalf of a company,  please drop us an email at opensource@newrelic.com.

## License

Open Install Library is licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.
