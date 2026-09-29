# NRDOT docs drift check

The NRDOT database recipes (`recipes/newrelic/infrastructure/nrdot/*-otel`) embed SQL
grants and collector configs copied from the public docs at docs.newrelic.com. When the
docs change, the recipes silently go stale. This check catches that and opens a PR.

It runs on a schedule via [`.github/workflows/docs-drift.yml`](../workflows/docs-drift.yml)
against a checkout of [newrelic/docs-website](https://github.com/newrelic/docs-website),
the source of docs.newrelic.com.

## What it checks

| Check | How |
|---|---|
| **Grants** | SQL privilege statements in the recipe's user-setup task vs. the SQL code blocks in the doc's "Configure database user" / "Grant monitoring privileges" sections. Normalised (`SYS.` prefix, `\$` escaping, `rdsadmin_util.grant_sys_object(...)`, `CONTAINER=ALL`) and compared as sets. |
| **Collector config** | The recipe's own `parse_instances` + `create_collector_config` bash tasks are **executed** in a sandbox against fixture instance files, and the resulting `oracle-config.yaml` is diffed against the doc's YAML. Covers database-only, host + database (preset 2) and multi-instance renders. Per-instance names (`nroracledb/2`, `resource/add_event_name/2`) are collapsed first; connection details and credentials are ignored. |
| **Doc links** | Every `docs.newrelic.com/docs/opentelemetry/...` URL in the recipe folder must resolve to a page (not a redirect) and its `#anchor` must exist. |

## Files

- `manifest.yml` — which doc page/section each recipe scenario is built from, and how to
  render each recipe (fixtures, template vars, temp files). **Add a product or scenario here.**
- `accepted-deviations.yml` — intentional differences (with a reason). These are listed in
  the report but not counted as drift.
- `drift_check.py` — the checker.

## Workflow behaviour

1. Runs weekdays at 03:30 UTC, or manually from the Actions tab (optionally for one product).
2. No drift: nothing happens.
3. Drift, and the `ANTHROPIC_API_KEY` secret is set: Claude edits the recipes, re-runs the
   check, and a PR is opened on the `docs-drift/nrdot` branch. Its body lists what was
   changed, what was left, and the full before/after reports. Later runs update the same PR.
4. Drift with no recipe changes (no API key, or nothing safe to fix): a single
   `docs-drift` issue is opened or updated with the report.

Nothing is merged automatically. Review each change against the linked doc section. The
docs can be wrong too; if so, add an entry to `accepted-deviations.yml` rather than
merging a bad change.

### Repository settings

| Setting | Required | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` secret | for auto-fix PRs | Lets Claude update the recipes. |
| `DOCS_DRIFT_TOKEN` secret | recommended | GitHub App token or fine-grained PAT (contents + pull requests: write). PRs opened with the default `GITHUB_TOKEN` don't trigger other workflows, so `validation.yml` wouldn't run on the drift PR. |
| `DOCS_DRIFT_MODEL` variable | no | Overrides the Claude model (default `claude-opus-5-5`). |
| Actions → "Allow GitHub Actions to create and approve pull requests" | yes | Needed when using `GITHUB_TOKEN`. |

## Run locally

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/newrelic/docs-website.git /tmp/docs-website
git -C /tmp/docs-website sparse-checkout set src/content/docs/opentelemetry
python3 -m venv /tmp/drift-venv && /tmp/drift-venv/bin/pip install -r .github/docs-drift/requirements.txt
/tmp/drift-venv/bin/python .github/docs-drift/drift_check.py --docs-repo /tmp/docs-website --product oracle
```

Writes `drift-report.md` and `drift-report.json`. Add `--fail-on-drift` for a non-zero exit.
