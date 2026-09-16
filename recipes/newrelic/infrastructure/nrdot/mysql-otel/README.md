# NRDOT MySQL Recipes

Recipes in this directory install the New Relic OpenTelemetry Distro (NRDOT) Collector
for MySQL/MariaDB monitoring:

| File | Topology | Collector host |
|---|---|---|
| `debian.yml` / `rhel.yml` | Self-hosted MySQL | Same host as the database(s) |
| `rds-debian.yml` / `rds-rhel.yml` | AWS RDS/Aurora MySQL | Separate host, connects to one or more RDS endpoints |

**Both topologies support monitoring multiple MySQL instances from a single collector.**
What "multiple instances" means differs by topology:
- **Self-hosted**: multiple separate MySQL server processes running on *this same host*
  (e.g. on different ports) — not multiple remote hosts. If you have MySQL running on
  several different machines, you install this recipe once per machine regardless; that
  doesn't need multi-instance support.
- **RDS**: multiple separate RDS/Aurora endpoints, monitored from one collector on a
  separate host.

Both share the same underlying mechanism: instead of prompting for one host/port/
credential set, you provide two files — an instances file and a secrets file — and any
instance that fails its checks is skipped (with a reason) rather than aborting the whole
install.

---

## Self-hosted (`debian.yml` / `rhel.yml`)

### Step 1: create the instances file

```yaml
instances:
  - host: localhost
    port: 3306
    login_name: newrelic
  - host: localhost
    port: 3307
    login_name: newrelic
```

If you're running a single MySQL server, this is still one entry. Add more entries only
if you run multiple separate MySQL server processes on this host (different ports).

Fields per instance:
- `host` — almost always `localhost`.
- `port` — the port that instance's `mysqld` listens on (`3306` is MySQL's default; a
  second local instance needs its own port, e.g. `3307`).
- `login_name` — the monitoring username the recipe will create/reuse on that instance.
  `newrelic` is fine to reuse across instances.

```bash
cat > ~/mysql-instances.yml << 'EOF'
instances:
  - host: localhost
    port: 3306
    login_name: newrelic
  - host: localhost
    port: 3307
    login_name: newrelic
EOF
```

### Step 2: create the secrets file

Each local instance has its own `root` password. Index them to match the instances
file's order:

```bash
umask 077
cat > ~/mysql-secrets.env << 'EOF'
NR_CLI_MYSQL_ROOT_PASSWORD_1=YourRootPassword1
NR_CLI_MYSQL_ROOT_PASSWORD_2=YourRootPassword2
EOF
chmod 600 ~/mysql-secrets.env
```
`NR_CLI_MYSQL_ROOT_PASSWORD_<i>` is required for every instance — there's no admin
*username* field here (self-hosted always connects as `root`, matching the single-
instance recipe this was extended from).

If `root`@`localhost` uses the `auth_socket` plugin (common on fresh Debian/Ubuntu
installs — no password, local-socket-only), switch it first on **each** instance:
```bash
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '<password>';"
```

### Step 3: run the install

```bash
sudo NEW_RELIC_API_KEY=<your-api-key> NEW_RELIC_ACCOUNT_ID=<your-account-id> \
  newrelic install -y --debug -n nrdot-collector-mysql \
  -c /path/to/debian.yml
```
(swap `rhel.yml` on a RHEL/CentOS host)

Prompts: `NRDOT configuration` (1=Standard, 2=Full-feature), instances file path,
secrets file path.

---

## AWS RDS/Aurora (`rds-debian.yml` / `rds-rhel.yml`)

### Step 1: create the instances file

```yaml
instances:
  - host: mydb1.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 3306
    login_name: newrelic
  - host: mydb2.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 3306
    login_name: newrelic
```

Fields per instance:
- `host` — the RDS/Aurora endpoint (from the RDS console; no `https://`, just the hostname).
- `port` — usually `3306` unless you changed it.
- `login_name` — the monitoring username the recipe will create/reuse on that instance.

```bash
cat > ~/mysql-instances.yml << 'EOF'
instances:
  - host: mydb1.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 3306
    login_name: newrelic
  - host: mydb2.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 3306
    login_name: newrelic
EOF
```

### Step 2: create the secrets file

Unlike self-hosted, RDS needs both a master **username** and password per instance
(there's no fixed account name):

```bash
umask 077
cat > ~/mysql-secrets.env << 'EOF'
NR_CLI_MYSQL_ADMIN_USER_1=admin
NR_CLI_MYSQL_ADMIN_PASSWORD_1=YourMasterPassword1
NR_CLI_MYSQL_ADMIN_USER_2=admin
NR_CLI_MYSQL_ADMIN_PASSWORD_2=YourMasterPassword2
EOF
chmod 600 ~/mysql-secrets.env
```
Both `NR_CLI_MYSQL_ADMIN_USER_<i>` and `NR_CLI_MYSQL_ADMIN_PASSWORD_<i>` are required for
every instance.

### Step 3: run the install

```bash
sudo NEW_RELIC_API_KEY=<your-api-key> NEW_RELIC_ACCOUNT_ID=<your-account-id> \
  newrelic install -y --debug -n nrdot-collector-mysql-rds \
  -c /path/to/rds-debian.yml
```
(swap `rds-rhel.yml` on a RHEL/CentOS host)

Prompts: `NRDOT configuration` (1=Standard, 2=Full-feature), instances file path,
secrets file path, and a CA certificate path (leave blank unless your RDS instances
enforce TLS with a custom CA bundle — this one prompt applies to every instance in the
run, since they're assumed to share the same regional CA bundle).

---

## What you get (both topologies)

One `nrdot-collector` service, one `mysql-config.yaml`, with a separate
`nrmysql/instance<N>` receiver and pipeline per instance that passed its checks. For 2+
instances, the receivers share their common settings (collection interval, TLS,
query/statement collection, event config) via a YAML anchor — only `endpoint`,
`username`, and `password` differ per instance — following the pattern documented at
https://docs.newrelic.com/docs/opentelemetry/database/mysql/multi-receiver/.

Check the result:
```bash
sudo systemctl status nrdot-collector
sudo cat /etc/nrdot-collector/mysql-config.yaml
```
The install's final output also prints a per-instance summary (`[OK]`/`[SKIP]` with a
reason for any skipped instance).

## Notes

- Any instance whose version check or user setup fails is skipped, not fatal — the
  install only fails outright if **every** instance fails.
- Re-running the install is safe: the monitoring user's creation SQL is idempotent
  (`CREATE USER IF NOT EXISTS` + `ALTER USER`), so there's no "reuse existing user?"
  prompt to answer.
- MySQL 5.7+ is required, with `performance_schema=ON` — checked per instance before
  any user is created.
