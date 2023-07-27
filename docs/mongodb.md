# Overview

The MongoDB recipe installs the [New Relic MongoDB Integration](https://docs.newrelic.com/docs/infrastructure/host-integrations/host-integrations-list/mongodb/mongodb-monitoring-integration-new/) and handles the scenarios mentioned below checking for them in the order listed:

- An open MongoDB server (for dev/testing purposes)
- A MongoDB server with regular (SCRAM) credentials-based authentication
- A MongoDB server with SSL/TLS authentication enabled

If you need to test the MongoDB recipe instrumentation in any of these scenarios, below are the steps for creating MongoDB instances for each one of them.

## Testing Instrumenting a MongoDB Server (No Authentication Enabled)

1. You may use [demo-deployer](https://github.com/newrelic/demo-deployer) to start a mongodb server instance by using something like this:
    ```sh
    ruby main.rb -c configs/credentials.json -d open-install-library/test/manual/definitions/ohi/linux/mongodb-debian.json
    ```

2. Once your mongodb instance is up, open mongo's config file and check these lines are commented out or absent:
    ```sh
    replication:
      replSetName: test
    ```

3. Then restart mongodb with `sudo systemctl restart mongod` (or similar command) and run the MongoDB recipe instrumentation install, for example:
    ```sh
    curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY=<API_KEY> NEW_RELIC_ACCOUNT_ID=<ACCOUNT_ID> NEW_RELIC_REGION=<REGION> /usr/local/bin/newrelic install -n mongodb-open-source-integration

    ```

Alternatively, you can launch your own cloud resources, manually [install](https://www.mongodb.com/docs/manual/installation/) and [configure](https://www.mongodb.com/docs/manual/reference/configuration-options/) MongoDB and then run the recipe installation.

## Testing Instrumenting a MongoDB Server with [SCRAM](https://www.mongodb.com/docs/manual/core/security-scram/) Authentication Enabled

For this case, please do the following:

1. Follow steps 1, 2 and 3 from the previous case.
2. Additionally, connect to MongoDB by using the [mongo shell](https://www.mongodb.com/docs/mongodb-shell/) available in your test instance deployed through the manual definition. You may need to install the mongo shell if testing through other means or if your MongoDB version is not current.
3. Once connected to `mongod`, issue these commands which will create a `root` user account in the MongoDB server with username `sysadmin` and password `TestPassword123$`:
    ```sh
    use admin
    db.createUser({ 
        user: "sysadmin",
        pwd: "TestPassword123$",
        roles: [
            { role: "root", db: "admin" },
            { role: "userAdminAnyDatabase", db: "admin" }
        ] 
    })
    ```
    **IMPORTANT**: The credentials created in `step 3` are super-privileged. This should be used only for testing purposes. For any other situation you should create a more appropriate user account with less privileges.
4. Open again MongoDB's config file `/etc/mongod.conf` and add these 2 lines:
    ```sh
    security:
      authorization: enabled
    ```
5. Restart mongodb with `sudo systemctl restart mongod` (or similar command) and run the MongoDB integration install.
6. The recipe will prompt if using SCRAM credentials to authenticate. Please, answer 'Y' and follow the prompts. Provide the credentials created in `step 3`.

## Testing Instrumenting a MongoDB Server with SSL Authentication Enabled

This scenario is a little more difficult to test as it requires creating the CA and related certificates. The following links below were helpful, in case you want to take a look at them: 

- https://www.mongodb.com/docs/manual/appendix/security/appendixA-openssl-ca/
- https://www.mongodb.com/docs/manual/appendix/security/appendixB-openssl-server/
- https://www.mongodb.com/docs/manual/appendix/security/appendixC-openssl-client/

The steps on those links above are summarized for your convenience as follows:

1. In your MongoDB server, create a `ca` folder for example: `/home/admin/ca`.
2. Create the `.cnf` files with their appropriate content as mentioned in the initial steps in the MongoDB documentation links above to the folder created in `step 1`.
3. One of those `.cnf` files is `openssl-test-server.cnf`. Open it and go to the `alt-names` section of this file to update the `DNS/IP` details of your MongoDB server/instance. After updating it, it should look similar to this example:
    ```sh
    ...
    [ alt_names ]
    DNS.1 = ip-172-31-6-44
    DNS.2 = localhost
    IP.1 = 172.31.6.44
    IP.2 = 127.0.0.1  
    ...
    ```
4. Save the following commands into a `setup.sh` file inside the `ca` folder, grant execution permissions and run it. You will be prompted 4 times to enter `distinguish names` for the certificates to be created. Make sure to enter some test, non-repeated, unique values each time you are prompted. At the end, this shell script will generate all needed `.key`, `.pem`, `.crt`, `.csr` files.
    ```sh
    # Clean up
    rm *.crt *.key *.csr *.key *.srl *.pem
    # Part 1: https://www.mongodb.com/docs/manual/appendix/security/appendixA-openssl-ca/
    # Create the test CA key file mongodb-test-ca.key
    openssl genrsa -out mongodb-test-ca.key 4096
    # Create the CA certificate mongod-test-ca.crt using the generated key file
    openssl req -new -x509 -days 1826 -key mongodb-test-ca.key -out mongodb-test-ca.crt -config openssl-test-ca.cnf
    # Create the private key for the intermediate certificate
    openssl genrsa -out mongodb-test-ia.key 4096
    # Create the certificate signing request for the intermediate certificate
    openssl req -new -key mongodb-test-ia.key -out mongodb-test-ia.csr -config openssl-test-ca.cnf
    # Create the intermediate certificate mongodb-test-ia.crt 
    openssl x509 -sha256 -req -days 730 -in mongodb-test-ia.csr -CA mongodb-test-ca.crt -CAkey mongodb-test-ca.key -set_serial 01 -out mongodb-test-ia.crt -extfile openssl-test-ca.cnf -extensions v3_ca
    # Create the test CA PEM file from the test CA certificate mongod-test-ca.crt and test intermediate certificate mongodb-test-ia.crt
    cat mongodb-test-ca.crt mongodb-test-ia.crt  > test-ca.pem

    # Part 2: https://www.mongodb.com/docs/manual/appendix/security/appendixB-openssl-server/
    # Create the test key file mongodb-test-server1.key
    openssl genrsa -out mongodb-test-server1.key 4096
    # Create the test certificate signing request mongodb-test-server1.csr
    openssl req -new -key mongodb-test-server1.key -out mongodb-test-server1.csr -config openssl-test-server.cnf
    # Create the test server certificate mongodb-test-server1.crt
    openssl x509 -sha256 -req -days 365 -in mongodb-test-server1.csr -CA mongodb-test-ia.crt -CAkey mongodb-test-ia.key -CAcreateserial -out mongodb-test-server1.crt -extfile openssl-test-server.cnf -extensions v3_req
    # Create the test PEM file for the server
    cat mongodb-test-server1.crt mongodb-test-server1.key > test-server1.pem

    # Part 3:https://www.mongodb.com/docs/manual/appendix/security/appendixC-openssl-client/
    # Create the test key file mongodb-test-client.key
    openssl genrsa -out mongodb-test-client.key 4096
    # Create the test certificate signing request mongodb-test-client.csr
    openssl req -new -key mongodb-test-client.key -out mongodb-test-client.csr -config openssl-test-client.cnf
    # Create the test client certificate mongodb-test-client.crt
    openssl x509 -sha256 -req -days 365 -in mongodb-test-client.csr -CA mongodb-test-ia.crt -CAkey mongodb-test-ia.key -CAcreateserial -out mongodb-test-client.crt -extfile openssl-test-client.cnf -extensions v3_req
    # Create the test PEM file for the client
    cat mongodb-test-client.crt mongodb-test-client.key > test-client.pem
    ```
5. In your `mongod.conf` file, make sure to disable SCRAM authentication, if enabled, and add the following lines. Note the paths to you newly create certificates:
    ```sh
    net:
      tls:
        mode: requireTLS
        certificateKeyFile: /home/admin/ca/test-server1.pem
        CAFile: /home/admin/ca/test-ca.pem
    ```
6. You may need also to update your `mongod.conf` file with the following to allow connections from any host:
    ```sh
    net:
      port: 27017
      bindIp: 0.0.0.0
    ```
7. Restart your `mongodb` service.
   
    **IMPORTANT**: If the MongoDB service does not start due to insufficient permissions to read the certificates, you may want to check the certificates permissions or move them
    to another location, like `/etc/ssl/certs` (depending on your linux distribution) to use more appropriate system-wide PKI permissions/settings.
8. Make sure you are in the `ca` folder and test connecting to mongo by issuing the following command (the recipe uses version 4.0). Note that the --host value needs to match with the update you made in `step 3` (as certificates hostnames will be checked):
   ```ssh
    # Mongo version 4.2 or greater:
    mongosh --tls --host ip-172-31-11-35:27017 --tlsCertificateKeyFile test-client.pem --tlsCAFile test-ca.pem

    # Mongo version 4.0:
    mongosh --ssl --host ip-172-31-11-35:27017 --sslPEMKeyFile test-client.pem --sslCAFile test-ca.pem
   ```
9. If you can connect with the previous command, you are ready to run the MongoDB recipe integration install and test this SSL/TLS scenario:
- Type 'N' when asked about SCRAM authentication.
- Type 'Y' when prompted about SSL/TLS authentication and follow the prompts to provide:
    - `Hostname` (should be your MongoDB test instance hostname),
    - `SSL CA Certificate Path` (e.g.: /home/admin/ca/test-ca.pem), and 
    - `Client Certificate Path` (e.g.: /home/admin/ca/test-client.pem)