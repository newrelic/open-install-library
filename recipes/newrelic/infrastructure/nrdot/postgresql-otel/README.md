# NRDOT PostgreSQL Recipes

Recipes in this directory install the New Relic OpenTelemetry Distro (NRDOT) Collector
for PostgreSQL monitoring:

| File | Topology | Collector host |
|---|---|---|
| `debian.yml` / `rhel.yml` | Self-hosted PostgreSQL | Same host as the database(s) |
| `rds-debian.yml` / `rds-rhel.yml` | AWS RDS/Aurora PostgreSQL | Separate host, connects to one or more RDS endpoints |

**Both topologies support monitoring multiple PostgreSQL instances from a single
collector.** What "multiple instances" means differs by topology:
- **Self-hosted**: multiple separate PostgreSQL server processes running on *this same
  host* (e.g. on different ports) — not multiple remote hosts.
- **RDS**: multiple separate RDS/Aurora endpoints, monitored from one collector on a
  separate host.

Both share the same underlying mechanism: instead of prompting for one host/port/
credential/database set, you provide two files — an instances file and a secrets file.
Each PostgreSQL instance also needs its own **list of databases** to monitor. Any
instance that fails its checks (version, missing databases, role setup) is skipped
(with a reason) rather than aborting the whole install.

---

## Self-hosted (`debian.yml` / `rhel.yml`)

### Step 1: create the instances file

```yaml
instances:
  - host: localhost
    port: 5432
    login_name: newrelic
    databases: [app1, app2]
  - host: localhost
    port: 5433
    login_name: newrelic
    databases: [app3]
```

If you're running a single PostgreSQL server, this is still one entry. Add more entries
only if you run multiple separate PostgreSQL server processes on this host (different
ports).

Fields per instance:
- `host` — almost always `localhost`.
- `port` — the port that instance listens on (`5432` is PostgreSQL's default; a second
  local instance needs its own port, e.g. `5433`).
- `login_name` — the monitoring role the recipe will create/reuse on that instance.
- `databases` — **must be written as an inline list** (`[db1, db2]`, on one line). At
  least one database is required; `postgres` is always configured automatically in
  addition to whatever you list.

```bash
cat > ~/postgres-instances.yml << 'EOF'
instances:
  - host: localhost
    port: 5432
    login_name: newrelic
    databases: [app1, app2]
  - host: localhost
    port: 5433
    login_name: newrelic
    databases: [app3]
EOF
```

### Step 2: create the secrets file

Each local instance has its own `postgres` superuser password. Index them to match the
instances file's order:

```bash
umask 077
cat > ~/postgres-secrets.env << 'EOF'
NR_CLI_POSTGRES_SUPERUSER_PASSWORD_1=YourSuperuserPassword1
NR_CLI_POSTGRES_SUPERUSER_PASSWORD_2=YourSuperuserPassword2
EOF
chmod 600 ~/postgres-secrets.env
```
`NR_CLI_POSTGRES_SUPERUSER_PASSWORD_<i>` is required for every instance — there's no
admin *username* field here (self-hosted always connects as `postgres`).

A fresh install has no password set on `postgres` by default — set one first on **each**
instance:
```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '<password>';"
```
and make sure `pg_hba.conf` permits password-based host authentication
(md5/scram-sha-256) for TCP connections (RHEL/CentOS defaults often don't).

### Step 3: run the install

```bash
sudo NEW_RELIC_API_KEY=<your-api-key> NEW_RELIC_ACCOUNT_ID=<your-account-id> \
  newrelic install -y --debug -n nrdot-collector-postgresql \
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
    port: 5432
    login_name: newrelic
    databases: [app1, app2]
  - host: mydb2.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 5432
    login_name: newrelic
    databases: [app3]
```

Same fields as self-hosted, except `host` is the RDS/Aurora endpoint instead of
`localhost`.

```bash
cat > ~/postgres-instances.yml << 'EOF'
instances:
  - host: mydb1.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 5432
    login_name: newrelic
    databases: [app1, app2]
  - host: mydb2.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 5432
    login_name: newrelic
    databases: [app3]
EOF
```

### Step 2: create the secrets file

Unlike self-hosted, RDS needs both a master **username** and password per instance:

```bash
umask 077
cat > ~/postgres-secrets.env << 'EOF'
NR_CLI_POSTGRES_ADMIN_USER_1=postgres
NR_CLI_POSTGRES_ADMIN_PASSWORD_1=YourMasterPassword1
NR_CLI_POSTGRES_ADMIN_USER_2=postgres
NR_CLI_POSTGRES_ADMIN_PASSWORD_2=YourMasterPassword2
EOF
chmod 600 ~/postgres-secrets.env
```
Both `NR_CLI_POSTGRES_ADMIN_USER_<i>` and `NR_CLI_POSTGRES_ADMIN_PASSWORD_<i>` are
required for every instance.

### Step 3: run the install

```bash
sudo NEW_RELIC_API_KEY=<your-api-key> NEW_RELIC_ACCOUNT_ID=<your-account-id> \
  newrelic install -y --debug -n nrdot-collector-postgresql-rds \
  -c /path/to/rds-debian.yml
```
(swap `rds-rhel.yml` on a RHEL/CentOS host)

Prompts: `NRDOT configuration` (1=Standard, 2=Full-feature), instances file path,
secrets file path.

---

## What you get (both topologies)

One `nrdot-collector` service, one `postgresql-config.yaml`, with a separate
`nrpostgresql/db<N>` receiver and pipeline per instance that passed its checks (`db<N>`
numbers instances by position, matching New Relic's own documented naming — it isn't
related to the `databases` field). For 2+ instances, the receivers share their common
settings (collection interval, event/query collection, metrics) via a YAML anchor —
`endpoint`, `username`, `password`, and `databases` differ per instance — following the
pattern documented at
https://docs.newrelic.com/docs/opentelemetry/database/postgresql/multi-receiver/.

Check the result:
```bash
sudo systemctl status nrdot-collector
sudo cat /etc/nrdot-collector/postgresql-config.yaml
```
The install's final output also prints a per-instance summary (`[OK]`/`[SKIP]` with a
reason for any skipped instance).

## Notes

- Any instance whose version check, database check, or role setup fails is skipped, not
  fatal — the install only fails outright if **every** instance fails.
- Re-running the install is safe: the monitoring role's creation SQL is idempotent
  (`IF NOT EXISTS` guarded `CREATE ROLE`, unconditional `ALTER ROLE`), so there's no
  "reuse existing user?" prompt to answer.
- PostgreSQL 14+ is required, with `pg_stat_statements` in `shared_preload_libraries` —
  checked per instance before any role is created.
- RDS/Aurora only: expect recurring `pg_hba.conf rejects connection ... database
  "rdsadmin"` lines in the collector logs for every instance — this doesn't affect
  metric or query-sample collection (see the RDS recipe's `postInstall` note for why).
