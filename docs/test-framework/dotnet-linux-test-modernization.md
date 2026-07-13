# Design: Modernize .NET APM Agent Linux Test Definitions

**Date:** 2026-06-25
**Branch:** `chore/update-dotnet-agent-test-definitions-linux`
**Status:** Approved (design); pending implementation plan

## Problem

The three existing test definitions that validate the New Relic .NET APM agent on
Linux all target end-of-life or near-EOL software at multiple layers:

| File | Region | Distro | Runtime installed | App artifact | Agent validation |
|---|---|---|---|---|---|
| `test/definitions/apm/dotNet/linux/linux2-aspnetcore5.json` | US | Amazon Linux 2 (EOL ~2026-06) | .NET SDK 7.0 + ASP.NET Core 7.0 via **CentOS 7 RPM** (7.0 EOL) | `net5webapplication` (.NET 5, EOL 2022-05) | **none — no `instrumentations` block** |
| `test/definitions-eu/apm/dotNet/linux/ubuntu20-apache-aspnetcore.json` | EU | Ubuntu 20.04 Focal (standard support ended 2025-04) | ASP.NET Core 8.0 | `net5webapplication` | infra + `apm/dotNet/linux-systemd` |
| `test/definitions-jp/apm/dotNet/linux/ubuntu20-apache-aspnetcore.json` | JP | Ubuntu 20.04 Focal | ASP.NET Core 8.0 | `net5webapplication` | infra + `apm/dotNet/linux-systemd` |

The US definition additionally has **no `instrumentations` block**, so it deploys the
app but never runs the install recipe or validates that the agent installed — it is
not actually testing the agent.

## Goals

- Test the .NET agent on **modern, supported Linux distros**: Ubuntu 24.04 (Noble) and
  Amazon Linux 2023.
- Deploy a **.NET 10** ASP.NET Core application (current LTS) instead of .NET 5.
- Every new definition includes a full `instrumentations` block that runs the install
  recipe and validates the agent (fixing the US gap).
- Cover **US, EU, and JP** regions.
- Add the new definitions first; **retire the old ones only after the new ones are
  green** (no coverage gap).

## Non-Goals

- Adding an nginx reverse-proxy variant (Apache only, matching today).
- arm64 coverage (the `apm/dotNet/linux-systemd` recipe targets `kernelArch: x86_64`).
- Refactoring deploy scripts beyond what serves this change.

## Key Decisions

1. **Strategy:** Add new definitions + retire old ones after the new set passes.
2. **Distros:** Ubuntu 24.04 (Noble) and Amazon Linux 2023.
3. **App runtime target:** .NET 10.
4. **Regions:** US, EU, JP.
5. **Region/distro matrix:** US gets both distros; EU and JP each get Ubuntu 24.04.
   → **4 new definitions.**
6. **Web server:** Apache only.
7. **App artifact:** external prerequisite — build/upload the .NET 10 zips to the
   `open-install-library-artifacts` S3 bucket outside this repo; **parameterize** the
   deploy scripts to consume them.
8. **Agent validation:** all four new definitions include the full `instrumentations`
   block.
9. **Deploy-script structuring:** **Approach A — parameterize the shared
   `apache/deploy-application/dotNet/{debian,rhel}` scripts** with behavior-preserving
   defaults, rather than cloning into version-specific dirs (Approach B).

## Verified Constraints (from exploration)

- `recipes/newrelic/apm/dotNet/linux-systemd.yml` has a wide-open install target
  (`os: linux`, `kernelArch: x86_64`, no platform/version restriction) → **no recipe
  changes needed**; it already accepts Ubuntu 24.04 and AL2023 on x86_64.
- `recipes/newrelic/infrastructure/awslinux.yml` already supports AL2023
  (`platformVersion: "(2023\.*)"`).
- `recipes/newrelic/infrastructure/ubuntu.yml` is version-agnostic → Ubuntu 24.04 fine.
- AMI name patterns for the target distros are already in use elsewhere in the repo and
  can be reused:
  - Ubuntu Noble: `ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-????????`
  - Amazon Linux 2023: `al2023-ami-2023.*-x86_64`
- The deployed apps are **prebuilt S3 zips** (`selfcontained-net5webapplication.zip`,
  `frameworkdependent-net5webapplication.zip`); there is **no app source in this repo**.

## Detailed Design

### 1. New test definitions (4 files)

All `t3.micro`, x86_64, two services behind Apache (self-contained `dotnet1` +
framework-dependent `dotnet2`), each with a full `instrumentations` block validating
`.NET Agent\s+(installed)`.

| File | Region | Distro | AMI pattern | `user_name` | Infra recipe URL |
|---|---|---|---|---|---|
| `test/definitions/apm/dotNet/linux/ubuntu24-apache-aspnetcore.json` | US | Ubuntu 24.04 | `ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-????????` | `ubuntu` | `.../infrastructure/ubuntu.yml` |
| `test/definitions/apm/dotNet/linux/al2023-apache-aspnetcore.json` | US | Amazon Linux 2023 | `al2023-ami-2023.*-x86_64` | `ec2-user` | `.../infrastructure/awslinux.yml` |
| `test/definitions-eu/apm/dotNet/linux/ubuntu24-apache-aspnetcore.json` | EU | Ubuntu 24.04 | (noble, as above) | `ubuntu` | `.../infrastructure/ubuntu.yml` |
| `test/definitions-jp/apm/dotNet/linux/ubuntu24-apache-aspnetcore.json` | JP | Ubuntu 24.04 | (noble, as above) | `ubuntu` | `.../infrastructure/ubuntu.yml` |

Each Ubuntu def's `services` reference:
- `dotNet/install/ubuntu24` (new runtime-install role)
- `apache/install/debian`
- `apache/deploy-application/dotNet/debian` (parameterized for .NET 10), self-contained + framework-dependent

The AL2023 def references:
- `dotNet/install/al2023` (new runtime-install role)
- `apache/install/rhel`
- `apache/deploy-application/dotNet/rhel` (parameterized for .NET 10)

`instrumentations` `recipe_content_url` chains the appropriate infra recipe +
`.../apm/dotNet/linux-systemd.yml`, with `validate_output: ".NET Agent\\s+\\(installed\\)"`.

### 2. New .NET 10 runtime-install roles

Under `test/deploy/linux/dotNet/install/`:

- **`ubuntu24/`** — mirrors the existing `ubuntu20` role (reads `/etc/os-release`,
  builds the `packages.microsoft.com` `.deb` URL), but installs
  **`aspnetcore-runtime-10.0`** instead of 8.0.
- **`al2023/`** — installs ASP.NET Core Runtime 10.0 on AL2023 using `dnf`.
  **⚠️ Highest-risk item.** The current `rhel` role uses a CentOS 7 RPM, which is wrong
  for AL2023. The exact package source must be confirmed during implementation
  (candidates, in preference order): AL2023 native `dotnet`/`aspnetcore-runtime-10.0`
  dnf packages; the `packages.microsoft.com` RHEL 9 feed; or `dotnet-install.sh`.
  Treated as an explicit verification spike before the AL2023 definition is finalized.

Only the ASP.NET Core **runtime** is required (the apps are ASP.NET Core web apps); no
SDK. The self-contained app does not need the runtime, but the framework-dependent app
does, so the runtime install remains necessary.

### 3. Parameterize `apache/deploy-application/dotNet/{debian,rhel}`

In `onbeforestart/tasks/main.yml` for both `debian` and `rhel`:

- Introduce `dotnet_app_name` (default `net5webapplication`) used to build
  `startup_command` (`/var/www/{{service_id}}/{{dotnet_app_name}}` and
  `.../{{dotnet_app_name}}.dll`).
- Keep `web_app_url` overridable (already is); the new defs pass the .NET 10
  self-contained / framework-dependent URLs. Defaults remain the net5 URLs so the
  old defs keep working until retired.
- Update the human-readable `apache_service_description` strings to be version-neutral
  or driven by a param.

The new definitions pass `dotnet_app_name` + the .NET 10 artifact URLs via service
`params`. The published entrypoint name inside the new zips must match
`dotnet_app_name`.

Verify the `rhel` `.service` template's `User=` value is correct for AL2023 (the
`debian` template hardcodes `User=ubuntu`; the AL2023 service must run as a user that
exists and owns `/var/www/...`).

### 4. Apache install (reuse)

- Ubuntu 24.04 → existing `apache/install/debian` (apt, `apache2`). Expected to work on
  Noble.
- AL2023 → existing `apache/install/rhel` (`yum install httpd`; `yum` aliases to `dnf`
  on AL2023). Verify it succeeds on AL2023.

### 5. External prerequisite — .NET 10 app artifacts (out of repo)

Build a .NET 10 ASP.NET Core sample web app in two flavors and upload to the
`open-install-library-artifacts` S3 bucket (us-west-2):

- `selfcontained-net10webapplication.zip` (self-contained, bundles runtime)
- `frameworkdependent-net10webapplication.zip` (framework-dependent)

Published entrypoint name (e.g. `net10webapplication` for the dll/executable) must match
the `dotnet_app_name` the new definitions pass. This work happens outside this repo and
requires S3 upload access; the repo wiring proceeds against the agreed names, but the
new tests cannot pass until the artifacts exist.

### 6. Retirement (after the 4 new defs are green)

Delete, only after confirming no other definitions reference them:

- `test/definitions/apm/dotNet/linux/linux2-aspnetcore5.json`
- `test/definitions-eu/apm/dotNet/linux/ubuntu20-apache-aspnetcore.json`
- `test/definitions-jp/apm/dotNet/linux/ubuntu20-apache-aspnetcore.json`
- `test/deploy/linux/dotNet/install/ubuntu20/` and `test/deploy/linux/dotNet/install/rhel/`
  (orphaned runtime-install roles) — **only if** no remaining definition references them.
- Any net5-only template cruft left behind once the parameterization defaults are no
  longer needed.

## Error Handling / Edge Cases

- **AL2023 .NET 10 install** is the primary failure risk → verification spike (§2).
- **AL2023 service user** mismatch in the `.service` template → verify (§3).
- **AMI availability per region** — the noble/al2023 AMI glob patterns must resolve in
  EU and JP regions, not just US. Verify during implementation.
- **Artifact naming coupling** — deploy-script `dotnet_app_name` must exactly match the
  published entrypoint inside the S3 zips.

## Testing / Validation

- Each new definition is exercised by the repo's existing validator harness (deploy →
  run install recipe → assert `.NET Agent (installed)` → app reachable via Apache).
- The two-app pattern (self-contained + framework-dependent) preserves coverage of both
  deployment models.
- Retirement step gated on the new definitions passing in their respective regions.

## Open Items Tracked Into the Plan

1. Confirm the AL2023 .NET 10 ASP.NET Core runtime install path (spike).
2. Confirm `apache/install/rhel` works unmodified on AL2023.
3. Confirm the `rhel` `.service` template user for AL2023.
4. Confirm noble + al2023 AMI patterns resolve in EU and JP.
5. Agree exact S3 artifact names + published entrypoint name; build/upload (external).
6. Confirm no other definitions consume the install/deploy roles slated for retirement.
