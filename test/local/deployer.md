# Local Testing - Deployer

The [Deployer](https://github.com/newrelic/demo-deployer) should be run through docker, to minimize the dependencies to install locally.

## Prerequisites

* Create your [User Config](https://github.com/newrelic/demo-deployer/blob/main/documentation/user_config/README.md) file which contains all the credentials for your cloud provider (AWS) and newrelic.

## Run

A docker image of the `Deployer` is published to [GitHub Container Registry](https://github.com/orgs/newrelic/packages/container/package/deployer).
All you need to do is to place your user config files, and any related secret (pem key file for example) to a local folder on your machine for example `/home/[username]/configs` and mount that folder when executing the docker command to run the deployer.

```bash
docker run -it\
    -v $HOME/configs/:/mnt/deployer/configs/\
    --entrypoint ruby deployer main.rb -c configs/<user config filename>.json -d https://raw.githubusercontent.com/newrelic/open-install-library/main/test/definitions/awslinux2-infra.json
```

## Debug

If you need to look into the details when running the recipe or validation, you should run the deployer through docker by launching it with a `sh` command, then run the deployer once the shell is started. The output of the deployer is stored under the image `/tmp` folder in a path that looks like `/tmp/[username]-[deployname]/`

```bash
docker run -it\
    -v $HOME/configs/:/mnt/deployer/configs/\
    --entrypoint sh deployer
```
