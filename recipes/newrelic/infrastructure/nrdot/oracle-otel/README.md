# NRDOT Oracle Recipes

Recipes in this directory install the New Relic OpenTelemetry Distro (NRDOT) Collector
for Oracle Database monitoring:

| File | Topology | Collector host |
|---|---|---|
| `oci-linux.yml` | Self-hosted Oracle | Runs from wherever the CLI is invoked; reaches each Oracle host over SSH and installs/configures the collector there |
| `rds-debian.yml` / `rds-rhel.yml` | AWS RDS Oracle | Separate host, connects to one or more RDS endpoints |

Both topologies support **monitoring multiple Oracle instances from a single
collector**, using the same two-file input pattern described below.

## How multi-instance monitoring works

Instead of prompting for one host/port/credential/service set, these recipes ask for
two files:

1. An **instances file** (YAML) — the non-secret connection details for every Oracle
   instance to monitor, in the order you want them numbered.
2. A **secrets file** (`KEY=VALUE` per line) — credentials needed once per instance to
   create the monitoring user, indexed to match the instances file's order. What this
   file needs to contain differs by topology — see each section below.

One collector, one `oracle-config.yaml`, and one `nrdot-collector` service end up
monitoring every instance you listed. If an instance fails its version check or user
setup, it's skipped (with a reason) rather than aborting the whole install — the rest
still get configured.

---

## AWS RDS (`rds-debian.yml` / `rds-rhel.yml`)

### Step 1: create the instances file

Create a YAML file (any path/name — you'll be prompted for its path during install)
listing every RDS Oracle instance to monitor:

```yaml
instances:
  - host: rds-orders.abcdef123.us-east-1.rds.amazonaws.com
    port: 1521
    service: ORDERSDB
    login_name: newrelic
  - host: rds-billing.abcdef123.us-east-1.rds.amazonaws.com
    port: 1521
    service: BILLINGDB
    login_name: newrelic
```

Fields per instance:
- `host` — the RDS Oracle endpoint (from the RDS console; no `https://`, just the hostname).
- `port` — usually `1521` unless you changed it.
- `service` — the Oracle service name (DB identifier) for that instance, not the RDS
  instance identifier.
- `login_name` — the monitoring username the recipe will create/reuse on that instance.
  `newrelic` is fine to reuse across instances; they're separate DB users on separate
  instances, so there's no collision.

Create it directly from a shell:
```bash
cat > ~/oracle-instances.yml << 'EOF'
instances:
  - host: rds-orders.abcdef123.us-east-1.rds.amazonaws.com
    port: 1521
    service: ORDERSDB
    login_name: newrelic
  - host: rds-billing.abcdef123.us-east-1.rds.amazonaws.com
    port: 1521
    service: BILLINGDB
    login_name: newrelic
EOF
```

### Step 2: create the secrets file

Create a plain `KEY=VALUE` file with the RDS **master** credentials for each instance,
indexed to match the instances file's order (index `1` = first entry above, `2` = second,
and so on):

```
NR_CLI_ORACLE_ADMIN_USER_1=admin
NR_CLI_ORACLE_ADMIN_PASSWORD_1=YourMasterPassword1
NR_CLI_ORACLE_ADMIN_USER_2=admin
NR_CLI_ORACLE_ADMIN_PASSWORD_2=YourMasterPassword2
```

Both `NR_CLI_ORACLE_ADMIN_USER_<i>` and `NR_CLI_ORACLE_ADMIN_PASSWORD_<i>` are
**required** for every instance listed in the instances file — an instance missing
either one is skipped before the recipe even attempts to connect to it.

Optional per instance: `NR_CLI_ORACLE_LOGIN_PASSWORD_<i>=SomeFixedPassword` — sets the
monitoring user's password explicitly instead of letting the recipe auto-generate a
random one. Leave it unset (the common case) to auto-generate.

The recipe sources this file directly — it does not need to be valid shell beyond plain
`KEY=VALUE` assignment.

Create it with restrictive permissions from the start:
```bash
umask 077
cat > ~/oracle-secrets.env << 'EOF'
NR_CLI_ORACLE_ADMIN_USER_1=admin
NR_CLI_ORACLE_ADMIN_PASSWORD_1=YourMasterPassword1
NR_CLI_ORACLE_ADMIN_USER_2=admin
NR_CLI_ORACLE_ADMIN_PASSWORD_2=YourMasterPassword2
EOF
chmod 600 ~/oracle-secrets.env   # redundant with umask, but explicit
```

If the file ends up group/world-readable, the recipe prints a warning (and tells you the
exact `chmod` to run) but still proceeds — it's a warning, not a hard failure. The
recipe never deletes this file (it's yours to manage and may be reused across
reinstalls).

### Step 3: run the install

```bash
sudo NEW_RELIC_API_KEY=<your-api-key> NEW_RELIC_ACCOUNT_ID=<your-account-id> \
  newrelic install -y --debug -n nrdot-collector-oracle-rds \
  -c /path/to/rds-debian.yml
```
(swap `rds-rhel.yml` on a RHEL/CentOS/OEL host)

You'll be prompted for:
1. `NRDOT configuration - 1) Database only  2) Host + Database` — pick `1` for a minimal
   Oracle-only config, `2` to also collect host-level metrics.
2. `Path to the Oracle RDS instances YAML file` — the absolute path to the file from Step 1.
3. `Path to the Oracle RDS secrets file` — the absolute path to the file from Step 2.

---

## Self-hosted via SSH (`oci-linux.yml`)

This recipe doesn't run on the Oracle Database host itself — it runs from wherever the
CLI is invoked (e.g. your own OCI Linux control host) and reaches every Oracle Database
host over SSH, using **SSH agent forwarding** (`ssh -A`) plus OS-authenticated `sysdba`
access (`sudo su - oracle -c 'sqlplus / as sysdba'`) — no SYS password is ever collected.
The NRDOT collector package itself is installed and configured on the **first** host
you connect to, and monitors every instance listed, wherever each one lives.

Before running the install, connect to that host with agent forwarding so the same
forwarded key can reach every Oracle Database host you list:
```bash
ssh -A <ssh-user>@<this-host>
```
and make sure each `ssh_user` below can run `sudo su - oracle` on its host without a
password prompt.

### Step 1: create the instances file

```yaml
instances:
  - host: dbhost1.example.com
    port: 1521
    ssh_user: opc
    container_type: 1
    pdb_name:
    service: ORCLCDB
    login_name: newrelic
  - host: dbhost2.example.com
    port: 1521
    ssh_user: opc
    container_type: 2
    pdb_name: ORCLPDB1
    service: ORCLPDB1
    login_name: newrelic
```

Fields per instance:
- `host` — the Oracle Database host's SSH-reachable address.
- `port` — the Oracle listener port, usually `1521`.
- `ssh_user` — the OS user to SSH in as on that host (must be able to `sudo su - oracle`
  without a password prompt).
- `container_type` — `1` for CDB (creates a common `c##<login_name>` user visible across
  every PDB via `CONTAINER=ALL` grants) or `2` for PDB (creates a plain user scoped to
  one PDB).
- `pdb_name` — required only when `container_type` is `2`; leave blank for CDB.
- `service` — the Oracle service name to connect to for monitoring.
- `login_name` — the monitoring username the recipe will create/reuse (entered without
  the `c##` prefix even in CDB mode — the recipe adds it).

```bash
cat > ~/oracle-instances.yml << 'EOF'
instances:
  - host: dbhost1.example.com
    port: 1521
    ssh_user: opc
    container_type: 1
    pdb_name:
    service: ORCLCDB
    login_name: newrelic
  - host: dbhost2.example.com
    port: 1521
    ssh_user: opc
    container_type: 2
    pdb_name: ORCLPDB1
    service: ORCLPDB1
    login_name: newrelic
EOF
```

### Step 2: create the secrets file (optional)

Unlike RDS, there's **no admin password to collect at all** — the one-time grant step
authenticates entirely via SSH + OS-level SYSDBA access. The secrets file here is
optional and only lets you pin a specific monitoring password per instance instead of
letting the recipe auto-generate one:

```bash
umask 077
cat > ~/oracle-secrets.env << 'EOF'
NR_CLI_ORACLE_LOGIN_PASSWORD_1=SomeFixedPassword1
EOF
chmod 600 ~/oracle-secrets.env
```

Leave the secrets file path blank at the install prompt (or point it at a file that
doesn't exist) if you don't need to pin any passwords — every instance will
auto-generate its own.

### Step 3: run the install

```bash
sudo NEW_RELIC_API_KEY=<your-api-key> NEW_RELIC_ACCOUNT_ID=<your-account-id> \
  newrelic install -y --debug -n nrdot-collector-oracle \
  -c /path/to/oci-linux.yml
```

You'll be prompted for:
1. `NRDOT configuration - 1) Database only  2) Host + Database`.
2. `Path to the Oracle instances YAML file` — the absolute path to the file from Step 1.
3. `Path to an optional secrets file for password overrides` — the absolute path to the
   file from Step 2, or blank if you didn't create one.

---

## What you get (both topologies)

One `nrdot-collector` service, one `/etc/nrdot-collector/oracle-config.yaml`, with a
separate `nroracledb/<N>` receiver and pipeline pair per instance that passed its
checks. For 2+ instances, the receivers share their common settings (collection
interval, events, top-query/query-sample collection, the ~60-entry metrics list) via a
YAML anchor — only `endpoint`, `username`, `password`, and `service` differ per
instance — following the pattern documented at
https://docs.newrelic.com/docs/opentelemetry/database/otel-oracledb/#rds-multi-receiver-config.

Check the result:
```bash
sudo systemctl status nrdot-collector
sudo cat /etc/nrdot-collector/oracle-config.yaml
```
The install's final output also prints a per-instance summary (`[OK]`/`[SKIP]` with a
reason for any skipped instance).

## Notes

- Any instance whose version check or user setup fails is skipped, not fatal — the
  install only fails outright if **every** instance fails.
- Re-running the install and an instance's monitoring user already exists: you'll be
  prompted interactively, per instance, to either reuse the existing user (you'll be
  asked for its current password) or create a new username. This is the one step in
  either recipe that isn't fully unattended.
- Oracle Database 19c or later is required — checked per instance before any user is
  created.
- `oci-linux.yml` specifically: the SSH agent socket check runs once, up front, against
  the local session — not per instance. If it's missing, connect with
  `ssh -A <user>@<this-host>` and re-run. Each instance's SSH connectivity (and its
  `sudo su - oracle` access) is still checked independently, so one unreachable host is
  skipped without affecting the rest.
- A dedicated `sqlplus` pre-flight check isn't included for the RDS recipes — if it's
  missing from `PATH`, the first SQL step fails with a plain "command not found."
  Install Oracle Instant Client + SQL*Plus on the collector host first. `oci-linux.yml`
  doesn't need this locally since `sqlplus` runs on the remote Oracle host, not the
  collector host.
