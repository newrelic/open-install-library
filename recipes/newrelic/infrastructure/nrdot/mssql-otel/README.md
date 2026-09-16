# NRDOT MSSQL Recipes

Recipes in this directory install the New Relic OpenTelemetry Distro (NRDOT) Collector
for Microsoft SQL Server monitoring:

| File | Topology | Multi-instance? |
|---|---|---|
| `rds-debian.yml` / `rds-rhel.yml` | AWS RDS SQL Server, Linux collector host | ✅ Covered below |
| `debian.yml` / `rhel.yml` | Self-hosted SQL Server, Linux collector host | ✅ Covered below |
| `windows.yml` | Self-hosted SQL Server, Windows collector host (SQL auth) | ✅ Covered below — **not locally tested**, see caveat |
| `windows-rds.yml` | AWS RDS SQL Server, Windows collector host (SQL auth) | ✅ Covered below — **not locally tested**, see caveat |
| `windows-winauth.yml` / `windows-rds-winauth.yml` | Windows/gMSA authentication (either topology) | ⏸ Out of scope — no plan yet for mixing/choosing auth modes across instances |

**Windows caveat:** `windows.yml` and `windows-rds.yml` were implemented and had their
YAML structure and generated-config nesting verified carefully by hand, but — unlike
every other file in this set — the embedded PowerShell itself could not be executed
locally (no `pwsh` available in this environment) to confirm it runs correctly end to
end. Treat these two as needing a real test pass on Windows before trusting them in
production.

## How multi-instance monitoring works

Instead of prompting for one host/port/credential set, these recipes ask for two files:

1. An **instances file** (YAML) — the non-secret connection details for every instance
   you want monitored, in the order you want them numbered.
2. A **secrets file** (`KEY=VALUE` per line) — the admin credentials needed once per
   instance to create the monitoring login, indexed to match the instances file's
   order.

One collector, one `mssql-config.yaml`, and one `nrdot-collector` service end up
monitoring every instance you listed. If an instance fails its version check or login
setup, it's skipped (with a reason) rather than aborting the whole install — the rest
still get configured.

---

## Linux self-hosted (`debian.yml` / `rhel.yml`)

### Step 1: create the instances file

```yaml
instances:
  - host: localhost
    port: 1433
    login_name: newrelic
  - host: localhost
    port: 1434
    login_name: newrelic
```

If you're running a single SQL Server, this is still one entry. Add more entries only
if you run multiple separate SQL Server instances on this host (different ports).

```bash
cat > ~/mssql-instances.yml << 'EOF'
instances:
  - host: localhost
    port: 1433
    login_name: newrelic
  - host: localhost
    port: 1434
    login_name: newrelic
EOF
```

### Step 2: create the secrets file

Each local instance needs an admin login and password — any login with sysadmin
privileges works, it doesn't have to be `sa` (some environments disable the built-in
`sa` account entirely). Index them to match the instances file's order:

```bash
umask 077
cat > ~/mssql-secrets.env << 'EOF'
NR_CLI_MSSQL_ADMIN_USER_1=sa
NR_CLI_MSSQL_ADMIN_PASSWORD_1=YourAdminPassword1
NR_CLI_MSSQL_ADMIN_USER_2=sa
NR_CLI_MSSQL_ADMIN_PASSWORD_2=YourAdminPassword2
EOF
chmod 600 ~/mssql-secrets.env
```
Both `NR_CLI_MSSQL_ADMIN_USER_<i>` and `NR_CLI_MSSQL_ADMIN_PASSWORD_<i>` are required
for every instance.

### Step 3: run the install

```bash
sudo NEW_RELIC_API_KEY=<your-api-key> NEW_RELIC_ACCOUNT_ID=<your-account-id> \
  newrelic install -y --debug -n nrdot-collector-mssql \
  -c /path/to/debian.yml
```
(swap `rhel.yml` on a RHEL/CentOS host)

Prompts: `NRDOT configuration` (1=Standard, 2=Full-feature), instances file path,
secrets file path.

---

## Linux AWS RDS (`rds-debian.yml` / `rds-rhel.yml`)

### Step 1: create the instances file

```yaml
instances:
  - host: mydb1.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 1433
    login_name: newrelic
  - host: mydb2.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 1433
    login_name: newrelic
```

```bash
cat > ~/mssql-instances.yml << 'EOF'
instances:
  - host: mydb1.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 1433
    login_name: newrelic
  - host: mydb2.abcdefg12345.us-east-1.rds.amazonaws.com
    port: 1433
    login_name: newrelic
EOF
```

### Step 2: create the secrets file

Unlike self-hosted, RDS needs both a master **username** and password per instance:

```bash
umask 077
cat > ~/mssql-secrets.env << 'EOF'
NR_CLI_MSSQL_ADMIN_USER_1=admin
NR_CLI_MSSQL_ADMIN_PASSWORD_1=YourMasterPassword1
NR_CLI_MSSQL_ADMIN_USER_2=admin
NR_CLI_MSSQL_ADMIN_PASSWORD_2=YourMasterPassword2
EOF
chmod 600 ~/mssql-secrets.env
```

### Step 3: run the install

```bash
sudo NEW_RELIC_API_KEY=<your-api-key> NEW_RELIC_ACCOUNT_ID=<your-account-id> \
  newrelic install -y --debug -n nrdot-collector-mssql-rds \
  -c /path/to/rds-debian.yml
```
(swap `rds-rhel.yml` on a RHEL/CentOS host)

`sqlcmd` must already be on `PATH` (or under `/opt/mssql-tools18/bin` /
`/opt/mssql-tools/bin`) — this recipe doesn't install it for you.

---

## Windows self-hosted, SQL auth (`windows.yml`)

Same shape as Linux self-hosted — same instances file format, same secrets file format
(`NR_CLI_MSSQL_ADMIN_USER_<i>` / `NR_CLI_MSSQL_ADMIN_PASSWORD_<i>`), same install
prompts:

```powershell
sudo NEW_RELIC_API_KEY=<your-api-key> NEW_RELIC_ACCOUNT_ID=<your-account-id> `
  newrelic install -y --debug -n nrdot-collector-mssql -c C:\path\to\windows.yml
```
`sqlcmd.exe` must already be installed and on `PATH`. Must be run from an Administrator
PowerShell session.

---

## Windows AWS RDS, SQL auth (`windows-rds.yml`)

Same shape as Linux RDS — same instances file format, same secrets file format
(`NR_CLI_MSSQL_ADMIN_USER_<i>` / `NR_CLI_MSSQL_ADMIN_PASSWORD_<i>`), same install
prompts:

```powershell
sudo NEW_RELIC_API_KEY=<your-api-key> NEW_RELIC_ACCOUNT_ID=<your-account-id> `
  newrelic install -y --debug -n nrdot-collector-mssql-rds -c C:\path\to\windows-rds.yml
```

---

## What you get (all four topologies above)

One `nrdot-collector` process, one `mssql-config.yaml`, with a separate
`nrsqlserver/instance<N>` receiver and pipeline pair per instance that passed its
checks. For 2+ instances, the receivers share their common settings (collection
interval, metrics list, query/statement collection) via a YAML anchor — only
`username`, `password`, `server`, and `port` differ per instance.

There's no published New Relic multi-receiver doc for MSSQL yet (unlike Oracle, MySQL,
and PostgreSQL), so the `/instance<N>` naming mirrors MySQL's documented convention
rather than inventing something new. The original single-instance recipes also had no
per-instance resource-tagging processor at all — one was added (`resource/sqlserver/
instance<N>`, setting `server.address`/`server.port`) since without it, multiple
instances sharing one collector would have no way to distinguish whose metrics are
whose.

Check the result:
```bash
sudo systemctl status nrdot-collector          # Linux
sudo cat /etc/nrdot-collector/mssql-config.yaml
```
```powershell
Get-Service nrdot-collector                                        # Windows
Get-Content "C:\Program Files\nrdot-collector\mssql-config.yaml"
```
The install's final output also prints a per-instance summary (`[OK]`/`[SKIP]` with a
reason for any skipped instance).

## Notes

- Any instance whose version check or login setup fails is skipped, not fatal — the
  install only fails outright if **every** instance fails.
- Re-running the install is safe: the monitoring login's creation SQL is already
  idempotent (`IF NOT EXISTS ... ELSE ALTER LOGIN`), so there's no "reuse existing
  login?" prompt to answer.
- SQL Server 2017 or later (major version 14+) is required — checked per instance
  before any login is created.
- Windows Auth / gMSA recipes (`windows-winauth.yml`, `windows-rds-winauth.yml`) are
  explicitly out of scope for this multi-instance work — they raise a design question
  (can different instances use different auth modes in one run, or is one mode chosen
  for the whole batch?) that hasn't been decided yet.
