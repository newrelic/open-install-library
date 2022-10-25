[![Community Plus header](https://github.com/newrelic/opensource-website/raw/master/src/images/categories/Community_Plus.png)](https://opensource.newrelic.com/oss-category/#community-plus)

# Open Install Library

[![Non Regression Testing](https://github.com/newrelic/open-install-library/workflows/Non%20Regression%20Testing/badge.svg)](https://github.com/newrelic/open-install-library/actions)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/newrelic/open-install-library/blob/master/LICENSE)
[![Release](https://img.shields.io/github/v/release/newrelic/open-install-library?sort=semver)](https://github.com/newrelic/open-install-library/releases/latest)

A collection of recipes designed to support the automated installation and setup of New Relic products and integrations.

## Mission

Deliver a consistent user experience, open source ecosystem, and platform services that allow any engineer in the world:

- to go from inadequate monitoring
- to complete instrumentation of their environment
- to realizing a win with New Relic

in 5 minutes or less.

## Commands

```bash
# Installs the newrelic-cli and invokes the install command
# Replace <API_KEY> AND <ACCOUNT_ID> with your own
curl -Ls https://https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY=<API_KEY> NEW_RELIC_ACCOUNT_ID=<ACCOUNT_ID> /usr/local/bin/newrelic install
```

```PowerShell
[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls'; 
(New-Object System.Net.WebClient).DownloadFile("https://download.newrelic.com/install/newrelic-cli/scripts/install.ps1", "$env:TEMP\install.ps1"); & $env:TEMP\install.ps1; $env:NEW_RELIC_API_KEY='<API_KEY>'; $env:NEW_RELIC_ACCOUNT_ID='<ACCOUNT_ID>'; & 'C:\Program Files\New Relic\New Relic CLI\newrelic.exe' install
```

## Docs

Project documentation can be found under [docs](docs/README.md).

## Testing

The testing of recipes is automated, and those are tested on a freshly provisioned environment and re-provisioned on every test run.

Test definitions files are located under the path [test/definitions](test/definitions). Those definitions are used with the [Deployer](https://github.com/newrelic/demo-deployer) to provision all the required resources, run the recipe installation, validate the installation is feeding data into newrelic, and finally teardown all the provisioned resources.

More information about the test framework testing can be found at [Test Framework](docs/test-framework/README.md).

### Manual testing

Refer to [Manual Testing instructions](test/manual/readme.MD)

## Support

New Relic hosts and moderates an online forum where customers can interact with New Relic employees as well as other customers to get help and share best practices. Like all official New Relic open source projects, there's a related Community topic in the New Relic Explorers Hub. You can find this project's topic/threads here:

>Add the url for the support thread here

## Contributing

We encourage your contributions to improve [Open Install Library](https://github.com/newrelic/open-install-library)! Keep in mind when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. You only have to sign the CLA one time per project.
If you have any questions, or to execute our corporate CLA, required if your contribution is on behalf of a company,  please drop us an email at opensource@newrelic.com.

## License

Open Install Library is licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.
