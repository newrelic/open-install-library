# Manual testing

The recipe installation can be tested manually. To do so, the Deployer can be used to provisioned new hosts in AWS, using similar setup than the automated tests, without any instrumentation installed on them.

# Provision new set of hosts

Get the latest docker image of the Deployer

```bash
docker pull ghcr.io/newrelic/deployer:latest
```

Then start the provisioning of all hosts using the Deployer in batch mode.

Run the snippet below after replacing:
* The path `<absolute_path>` with the absolute path to the manual `definitions` folder (docker requires absolute path for mounting directories)
* The file `<my_user_config_filename>.json` with your actual deployer user config filename (assumed to be in your ~/configs folder)

```bash
docker run -i \
-v ~/configs/:/mnt/deployer/configs/ \
-v <absolute_path>/definitions/:/mnt/deployer/definitions/ \
--entrypoint ruby ghcr.io/newrelic/deployer:latest batch.rb -c configs/<my_user_config_filename>.json -d definitions -s 20 -m deploy -l debug
```

# Testing

Once all hosts are provisioned, you can SSH to the instance, and run the newrelic-cli as indicated from the UI.

## Windows

For the Windows host, you'll want to get the password from the AWS Console. While on the EC2 UI, right click the Windows instance, and click Connect. Then use your pem key to decrypt the password.
Once you have the password, use a `Remote Desktop Connection` client with the credential `Administrator` and the password you've decrypted in AWS.

# Tearing down

To teardown all the hosts, re-run the deployer in batch mode with the `-t` option.

Run the snippet below after replacing:
* The path `<absolute_path>` with the absolute path to the manual `definitions` folder (docker requires absolute path for mounting directories)
* The file `<my_user_config_filename>.json` with your actual deployer user config filename (assumed to be in your ~/configs folder)

```bash
docker run -i \
-v ~/configs/:/mnt/deployer/configs/ \
-v <absolute_path>/definitions/:/mnt/deployer/definitions/ \
--entrypoint ruby ghcr.io/newrelic/deployer:latest batch.rb -c configs/<my_user_config_filename>.json -d definitions -s 20 -m deploy -l debug -t
```
