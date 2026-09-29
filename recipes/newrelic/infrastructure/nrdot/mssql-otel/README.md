# NRDOT MSSQL Recipes

Recipes in this directory install the New Relic OpenTelemetry Distro (NRDOT) Collector
for Microsoft SQL Server monitoring:

| File | Topology | Multi-instance? |
|---|---|---|
| `rds-debian.yml` / `rds-rhel.yml` | AWS RDS SQL Server, Linux collector host | ✅ Covered below |
| `debian.yml` / `rhel.yml` | Self-hosted SQL Server, Linux collector host | ✅ Covered below |
| `windows.yml` | Self-hosted SQL Server, Windows collector host (SQL auth) | ✅ Covered below |
| `windows-rds.yml` | AWS RDS SQL Server, Windows collector host (SQL auth) | ✅ Covered below |
| `windows-winauth.yml` / `windows-rds-winauth.yml` | Windows Domain Auth / gMSA (self-hosted / AWS RDS) | ✅ Covered below — one auth mode and one Windows identity per install |

## How multi-instance monitoring works

Instead of prompting for one host/port/credential set, these recipes ask for two files:

1. An **instances file** (YAML) — the non-secret connection details for every instance
   you want monitored, in the order you want them numbered.
2. A **secrets file** (`KEY=VALUE` per line) — the admin credentials needed once per
   instance to create the monitoring login, indexed to match the instances file's
   order.

The Windows Domain Auth / gMSA recipes use only the instances file (no secrets file) —
see [their section](#windows-domain-auth--gmsa-windows-winauthyml--windows-rds-winauthyml).

One collector, one `mssql-config.yaml`, and one `nrdot-collector` service end up
monitoring every instance you listed. If an instance fails its version check or login
setup, it's skipped (with a reason) rather than aborting the whole install — the rest
still get configured.

> **Breaking change, no fallback:** these recipes previously took a single-instance set
> of flat inputVars — `NR_CLI_MSSQL_SERVER`, `NR_CLI_MSSQL_PORT`,
> `NR_CLI_MSSQL_SA_PASSWORD`, `NR_CLI_MSSQL_LOGIN_NAME` for self-hosted, plus
> `NR_CLI_MSSQL_MASTER_USER`/`NR_CLI_MSSQL_MASTER_PASSWORD` for RDS, and
> `NR_CLI_MSSQL_SERVER`/`NR_CLI_MSSQL_PORT` for the Windows Domain Auth / gMSA recipes
> (replaced by `NR_CLI_MSSQL_INSTANCES_FILE`; their auth prompts are unchanged). Those vars have
> been **removed entirely**, with no deprecated/compatibility path, in favor of the
> two-file pattern documented below. A scripted or `-y` install still setting the old
> vars will have them silently ignored and then fail with "Instances file not found"
> rather than a clear migration error. This is an intentional redesign, made while these
> recipes are still marked `WORK IN PROGRESS - not for use` — update any existing
> automation to the new instances-file/secrets-file inputs before relying on this
> recipe.

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

## Windows Domain Auth / gMSA (`windows-winauth.yml` / `windows-rds-winauth.yml`)

These recipes use Windows authentication (`integrated security=true`) instead of SQL
logins. The collector is one Windows service with one logon account, and it connects to
**every** instance as that account — so a multi-instance install always uses **one auth
mode and one Windows identity**, granted on every instance in the file. Different
identities per instance are not possible.

### Step 1: create the instances file

Same file for both recipes and every auth flow — only `host` and `port` per instance
(no `login_name`, no secrets file):

```yaml
instances:
  - host: sql01.contoso.com
    port: 1433
  - host: sql02.contoso.com
    port: 1433
```

For RDS, `host` is the RDS endpoint (e.g. `mydb.xxxxxxxxxx.us-east-1.rds.amazonaws.com`).

- **Named instances:** use `host` plus the instance's static TCP port, not
  `host\INSTANCE` (with a port, the connection goes straight to that port and ignores the
  instance name). Find the port in SQL Server Configuration Manager → SQL Server Network
  Configuration → Protocols for `<INSTANCE>` → TCP/IP → IP Addresses → IPAll → TCP Port
  (set a static port if it's dynamic), or run on that instance:
  `SELECT local_tcp_port FROM sys.dm_exec_connections WHERE session_id = @@SPID;`
- An entry with an invalid host (contains `;`, `'`, `"` or spaces), an invalid port, or a
  duplicate `host:port` is skipped with a reason.

### Step 2: answer the prompts

| Recipe / flow | Prompts that matter | Identity used for all instances |
|---|---|---|
| `windows-winauth.yml`, Windows Domain Auth, **same host** (`NR_CLI_MSSQL_AUTH_MODE=1`, `NR_CLI_MSSQL_WINAUTH_LOCATION=1`) | instances file only | The Windows user running the install (`SELECT SYSTEM_USER`); the service stays LocalSystem |
| `windows-winauth.yml`, Windows Domain Auth, **different host** (`=1`, `=2`) | `NR_CLI_MSSQL_WIN_ACCOUNT`, `NR_CLI_MSSQL_WIN_PASSWORD` | That domain account (service logon set once with `sc.exe`) |
| `windows-rds-winauth.yml`, Windows Domain Auth (`=1`) | `NR_CLI_MSSQL_WIN_ACCOUNT`, `NR_CLI_MSSQL_WIN_PASSWORD` | That domain account |
| Either recipe, gMSA (`=2`) | `NR_CLI_MSSQL_GMSA_ACCOUNT` (`DOMAIN\name$`) | That gMSA (no password — AD manages it) |

- **Same host lists only instances on this machine.** A remote entry would connect as the
  computer account (`DOMAIN\HOST$`) and silently send no data. Use "different host" (or
  gMSA) for remote or clustered (failover) instances.
- The Windows account running the install must be able to connect with Windows auth, and
  hold sysadmin (or equivalent), on every instance — grants run with `sqlcmd -E`.

### Step 3: run the install

```powershell
newrelic install -y --debug -n nrdot-collector-mssql-winauth -c C:\path\to\windows-winauth.yml
newrelic install -y --debug -n nrdot-collector-mssql-rds-winauth -c C:\path\to\windows-rds-winauth.yml
```
Must be run from an Administrator PowerShell session with `sqlcmd.exe` on `PATH`.

### How these differ from the SQL-auth recipes

- **One instance left → plain single-instance config.** The config is exactly what these
  recipes produced before multi-instance support (receiver `nrsqlserver`, pipelines
  `metrics`/`logs`, no `resource/sqlserver/...` processor). Two or more instances use the
  same `nrsqlserver/instance<N>` layout as below, with only `datasource` differing per
  instance.
- **Early stop.** If every instance fails its version check, the install stops before the
  collector is installed; if every instance fails its permission setup, it stops before
  the service logon is changed. (The SQL-auth recipes only stop at config creation.)
- **Same host:** per instance, the permission check runs first and the grant script runs
  only if something is `MISSING`. Anything still missing afterwards is shown as a warning
  in the summary.

### Production notes

- gMSA is recommended across many servers: AD rotates its password. With a domain account,
  update the service after a password change
  (`sc.exe config nrdot-collector obj= "DOMAIN\user" password= "<new>"`), or monitoring
  stops for all instances — and repeated failed logons can lock the account.
- "Cannot generate SSPI context" (different host / RDS) points to missing SQL Server SPNs.
- The same-host grants include `db_datareader` (per the New Relic docs), which allows
  reading table data.
- Many instances on one collector: consider raising `NR_MEM_LIMITER_LIMIT_MIB`
  (Standard preset default 200).

---

## What you get (all topologies above)

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
- Windows Domain Auth / gMSA recipes (`windows-winauth.yml`, `windows-rds-winauth.yml`):
  one auth mode and one Windows identity is chosen for the whole batch — see
  [their section](#windows-domain-auth--gmsa-windows-winauthyml--windows-rds-winauthyml)
  for how they differ from the SQL-auth recipes.
