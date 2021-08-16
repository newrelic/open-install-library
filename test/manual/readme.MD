# Manual testing

The recipe installation can be tested manually. To do so, the Deployer can be used to provisioned new hosts in AWS, using similar setup than the automated tests, without any instrumentation installed on them.

## Provision new set of hosts

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

## Testing

Once all hosts are provisioned, you can SSH to the instance, and run the newrelic-cli as indicated from the UI.

## Auto Config Default Params

Use the `ohi-auto-config` directory for provisioning instances with integrations already configured. When running `newrelic install`, these are the values to be used with the CLI prompts:

```bash
docker run -it \
  -v $HOME/configs/:/mnt/deployer/configs/ \
  -v <absolute_path>/open-install-library/test/manual/definitions/ohi-auto-config/:/mnt/deployer/ohi-auto-config/ \
  --entrypoint ruby ghcr.io/newrelic/deployer:latest batch.rb -c configs/<my_user_config_filename>.json -d ohi-auto-config -s 20 -m deploy -l debug
```

| Recipe        | Prompt Values                                                                                                                                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apache        | Status URL: http://127.0.0.1/server-status?auto                                                                                                                                                                                 |
| Cassandra     | Username: newrelic <br>Password: Virtuoso4all! <br>Hostname: localhost <br>Port: 7199                                                                                                                                           |
| Elasticsearch | Username: newrelic <br>Password: Virtuoso4all! <br>Hostname: localhost <br>Port: 9200 <br>Config file: /etc/elasticsearch/elasticsearch.yml <br>Use SSL to connect? (true/false): false <br>Default the rest (just press enter) |
| JMX (JBoss)   | Username: newrelic <br>Password: Virtuoso4all! <br>Hostname: localhost <br>Port: 9990 <br>Are you using SSL? (y/n): n <br>Default the rest (just press enter)                                                                   |
| MySQL         | Username: newrelic <br>Password: Virtuoso4all! <br>Hostname: localhost <br>Port: 3306 <br>Database Name: MysqlSample                                                                                                            |
| MS SQL        | Username: newrelic <br>Password: the RDP password used to logon <br>Hostname: 127.0.0.1 <br>Port: 1433                                                                                                                                           |
| Nginx         | NGINX status URL: http://127.0.0.1/status                                                                                                                                                                                       |
| Redis         | Hostname: localhost <br>Password: Virtuoso4all! <br>Port: 6379 <br>Keyspace Metrics: '{}'                                                                                                                                       |

## Windows

For the Windows host, you'll want to get the password from the AWS Console. While on the EC2 UI, right click the Windows instance, and click Connect. Then use your pem key to decrypt the password.
Once you have the password, use a `Remote Desktop Connection` client with the credential `Administrator` and the password you've decrypted in AWS.

## Tearing down

To teardown all the hosts, re-run the deployer in batch mode with the option `-m teardown` (instead of `-m deploy`).

Run the snippet below after replacing:

* The path `<absolute_path>` with the absolute path to the manual `definitions` folder (docker requires absolute path for mounting directories)
* The file `<my_user_config_filename>.json` with your actual deployer user config filename (assumed to be in your ~/configs folder)

```bash
docker run -i \
-v ~/configs/:/mnt/deployer/configs/ \
-v <absolute_path>/definitions/:/mnt/deployer/definitions/ \
--entrypoint ruby ghcr.io/newrelic/deployer:latest batch.rb -c configs/<my_user_config_filename>.json -d definitions -s 20 -m teardown -l debug
```

## macOS

NOTICE: According to [Apple's SLA](https://www.apple.com/legal/sla/), macOS should only be virtualized on a macOS system using official Apple hardware. Apart from legal reasons, the virtualization will simply not work in most other environments.

Install the required software:
- [Vagrant](https://www.vagrantup.com/downloads)
- [VirtualBox](https://www.virtualbox.org/)

Initialize a working directory and Vagrantfile:
```
mkdir macos-catalina
cd macos-catalina
vagrant init ramsey/macos-catalina
```

Add this line to the Vagrantfile (within the "Vagrant.configure" block of code):
```
config.vm.synced_folder ".", "/vagrant", disabled: true
```

Start the local instance:
```
vagrant up
```

Once started, there are two forms of access:
- ssh: while in the macos-catalina folder, run: `vagrant ssh`
- GUI: open the VirtualBox application, select the macos-catalina host and click Show (the vagrant user has password: `vagrant`)

This method of running a macOS host uses a [public GitHub project](https://github.com/ramsey/macos-vagrant-box) based off [macinbox](https://github.com/bacongravy/macinbox).
