#!/usr/bin/env python3
"""Detect drift between NRDOT database recipes and the public New Relic docs.

For every scenario in manifest.yml this compares, against a local checkout of
github.com/newrelic/docs-website:

  * grants  - the SQL privilege statements the recipe runs vs. the doc's SQL blocks
  * configs - the collector config the recipe actually renders (its own bash tasks are
              executed in a sandbox against fixture instance files) vs. the doc's YAML
  * links   - every docs.newrelic.com URL in the recipe folder still resolves to a page
              (not a redirect) and its #anchor still exists

Differences listed in accepted-deviations.yml are reported separately and don't count as
drift. Writes a Markdown report and a JSON result; exits 1 on drift with --fail-on-drift.
"""

import argparse
import copy
import fnmatch
import json
import os
import re
import subprocess
import sys
import tempfile

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


# ---------------------------------------------------------------------------
# Docs (MDX) extraction
# ---------------------------------------------------------------------------

def read_doc(docs_root, page):
    for candidate in (f"{page}.mdx", f"{page}/index.mdx", f"{page}.md"):
        path = os.path.join(docs_root, candidate)
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as f:
                return f.read()
    raise FileNotFoundError(f"doc page not found in docs checkout: {page}")


def doc_section(mdx, section=None, collapser=None):
    """Narrow an MDX page down to a `## Heading [#section]` and/or a `<Collapser id=...>`."""
    text = mdx
    if section:
        m = re.search(r"^#{2,6} .*\[#" + re.escape(section) + r"\]\s*$", text, re.M)
        if not m:
            raise LookupError(f"section [#{section}] not found")
        level = len(re.match(r"#+", text[m.start():]).group(0))
        rest = text[m.end():]
        end = re.search(r"^#{2," + str(level) + r"} ", rest, re.M)
        text = rest[: end.start()] if end else rest
    if collapser:
        m = re.search(r"<Collapser\b[^>]*\bid=\"" + re.escape(collapser) + r"\"[^>]*>", text, re.S)
        if not m:
            raise LookupError(f"collapser id=\"{collapser}\" not found")
        rest = text[m.end():]
        end = rest.find("</Collapser>")
        text = rest[: end if end >= 0 else None]
    return text


def doc_code_blocks(text, langs):
    return [m.group(2) for m in re.finditer(r"```(\w*)[^\n]*\n(.*?)```", text, re.S)
            if m.group(1).lower() in langs]


def doc_config_yaml(text):
    """The collector config from an <OtelConfig config={`...`}> component or a ```yaml block."""
    m = re.search(r"config=\{`(.*?)`\}", text, re.S)
    if m:
        raw = m.group(1)
    else:
        blocks = [b for b in doc_code_blocks(text, {"yaml", "yml"}) if re.search(r"^receivers:", b, re.M)]
        if not blocks:
            raise LookupError("no collector config found (neither OtelConfig nor ```yaml with receivers:)")
        raw = blocks[0]
    if m:
        # Inside a JS template literal `\${` and `\`` render as `${` and a backtick.
        raw = raw.replace("\\$", "$").replace("\\`", "`")
    # Placeholders such as <input3> or <YOUR_DB_HOST> aren't valid YAML scalars everywhere.
    raw = re.sub(r"<(input\d+|[A-Za-z_][A-Za-z0-9_\-]*)>", lambda p: f"PLACEHOLDER_{p.group(1)}", raw)
    return yaml.safe_load(raw)


# ---------------------------------------------------------------------------
# SQL privilege statement normalisation (shared by docs and recipes)
# ---------------------------------------------------------------------------

def _obj(name):
    name = name.strip().strip("'\"").replace("\\$", "$").upper()
    return re.sub(r"^SYS\.", "", name)


def sql_statements(text):
    """Return the set of normalised privilege-relevant statements found in text."""
    text = text.replace("\\$", "$")
    found = set()
    for m in re.finditer(r"\bGRANT\s+([A-Z_ ,]+?)\s+ON\s+([A-Z0-9_$.\"]+)\s+TO\s+(\S+?)(\s+CONTAINER\s*=\s*ALL)?\s*;",
                         text, re.I):
        for priv in m.group(1).split(","):
            found.add(("GRANT", priv.strip().upper(), _obj(m.group(2)), "CONTAINER=ALL" if m.group(4) else ""))
    for m in re.finditer(r"\bGRANT\s+([A-Z_ ,]+?)\s+TO\s+(\S+?)(\s+CONTAINER\s*=\s*ALL)?\s*;", text, re.I):
        if re.search(r"\sON\s", m.group(0), re.I):
            continue
        for priv in m.group(1).split(","):
            found.add(("GRANT", priv.strip().upper(), "", "CONTAINER=ALL" if m.group(3) else ""))
    for m in re.finditer(r"grant_sys_object\s*\(\s*'([^']+)'\s*,\s*'[^']*'\s*,\s*'([^']+)'", text, re.I):
        found.add(("GRANT", m.group(2).upper(), _obj(m.group(1)), "rdsadmin"))
    for m in re.finditer(r"\bALTER\s+USER\s+\S+\s+SET\s+CONTAINER_DATA\s*=\s*(\w+)(\s+CONTAINER\s*=\s*\w+)?", text, re.I):
        found.add(("ALTER USER", f"CONTAINER_DATA={m.group(1).upper()}",
                   re.sub(r"\s+", "", (m.group(2) or "")).upper(), ""))
    for m in re.finditer(r"\bCREATE\s+USER\s+\S+\s+IDENTIFIED\s+BY\s+\S+?(\s+CONTAINER\s*=\s*ALL)?\s*;", text, re.I):
        found.add(("CREATE USER", "", "", "CONTAINER=ALL" if m.group(1) else ""))
    return found


def fmt_stmt(s):
    kind, priv, obj, suffix = s
    if kind == "GRANT" and suffix == "rdsadmin":
        return f"rdsadmin_util.grant_sys_object('{obj}', ..., '{priv}')"
    if kind == "GRANT":
        return " ".join(p for p in ("GRANT", priv, f"ON {obj}" if obj else "", "TO <user>", suffix) if p)
    if kind == "ALTER USER":
        return f"ALTER USER <user> SET {priv} {obj}".strip()
    return f"CREATE USER <user> IDENTIFIED BY ... {suffix}".strip()


# ---------------------------------------------------------------------------
# Recipe extraction / rendering
# ---------------------------------------------------------------------------

def load_recipe(path):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def task_script(recipe, task):
    tasks = recipe["install"]["tasks"]
    if task not in tasks:
        raise LookupError(f"task '{task}' not in recipe")
    return "\n".join(c for c in tasks[task].get("cmds", []) if isinstance(c, str))


def heredoc_bodies(script):
    """Bodies of every heredoc in script; the whole script if it has none (e.g. printf lists)."""
    bodies = []
    for m in re.finditer(r"<<-?\s*['\"]?(\w+)['\"]?[^\n]*\n", script):
        end = re.search(r"^\s*" + m.group(1) + r"\s*$", script[m.end():], re.M)
        if end:
            bodies.append(script[m.end(): m.end() + end.start()])
    return bodies or [script]


def recipe_statements(recipe, spec):
    script = task_script(recipe, spec["task"])
    blocks = heredoc_bodies(script) if spec.get("heredoc", True) else [script]
    if spec.get("block_match"):
        blocks = [b for b in blocks if re.search(spec["block_match"], b)]
    if spec.get("block_exclude"):
        blocks = [b for b in blocks if not re.search(spec["block_exclude"], b)]
    blocks = [b for b in blocks if sql_statements(b)]
    if len(blocks) != 1:
        raise LookupError(f"expected exactly 1 grant block in task '{spec['task']}', found {len(blocks)} "
                          "- tighten block_match/block_exclude in manifest.yml")
    return sql_statements(blocks[0])


SHELL_PRELUDE = """
chown() { :; }
systemctl() { :; }
sudo() { "$@"; }
"""


def render_recipe_config(recipe, render, scenario, sandbox):
    """Run the recipe's own bash tasks against fixture files and return the parsed config."""
    os.makedirs(os.path.join(sandbox, "tmp"), exist_ok=True)
    os.makedirs(os.path.join(sandbox, "etc", "nrdot-collector"), exist_ok=True)

    def sb(path):
        return path.replace("/tmp/", f"{sandbox}/tmp/").replace("/etc/nrdot-collector", f"{sandbox}/etc/nrdot-collector")

    instances = scenario["instances"]
    instance_keys = render["instance_keys"]
    lines = ["instances:"]
    for inst in instances:
        for n, key in enumerate(instance_keys):
            value = inst.get(key, "")
            value = "" if value is None else str(value)
            lines.append(f"  {'- ' if n == 0 else '  '}{key}:{' ' + value if value != '' else ''}")
    instances_file = os.path.join(sandbox, "instances.yml")
    with open(instances_file, "w") as f:
        f.write("\n".join(lines) + "\n")

    secrets_file = os.path.join(sandbox, "secrets.env")
    with open(secrets_file, "w") as f:
        for i, _ in enumerate(instances, 1):
            # Keys only - recipes just check the values are non-empty, and the tasks that
            # would use them (connecting to Oracle) are never run.
            for line in render.get("secrets_per_instance", []):
                key = line.format(i=i).split("=", 1)[0]
                f.write(f"{key}=REDACTED\n")
    os.chmod(secrets_file, 0o600)

    for i, inst in enumerate(instances, 1):
        ctx = {"i": i, "sandbox": sandbox, **{k: ("" if v is None else v) for k, v in inst.items()}}
        if inst.get("wallet_dir"):
            wallet = inst["wallet_dir"].format(**ctx)
            os.makedirs(wallet, exist_ok=True)
            for name in ("cwallet.sso", "sqlnet.ora", "tnsnames.ora", "ewallet.p12"):
                open(os.path.join(wallet, name), "a").close()
        for path, content in render.get("per_instance_files", {}).items():
            target = sb(path.format(**ctx))
            with open(target, "w") as f:
                f.write(str(content).format(**ctx))

    variables = {**render.get("vars", {}), **scenario.get("vars", {})}
    variables = {k: str(v).format(instances_file=instances_file, secrets_file=secrets_file, sandbox=sandbox)
                 for k, v in variables.items()}

    for task in render["tasks"]:
        script = task_script(recipe, task)

        def sub(m):
            name = m.group(1)
            if name not in variables:
                raise KeyError(f"recipe template var {{{{.{name}}}}} used by task '{task}' has no value in manifest")
            return variables[name]

        script = re.sub(r"\{\{\s*\.(\w+)\s*\}\}", sub, script)
        script = sb(script)
        # Recipe instance fixtures may reference the sandbox (e.g. wallet_dir).
        script = SHELL_PRELUDE + script
        # Minimal environment: the recipe must not see the caller's credentials (API keys,
        # tokens) - everything it needs comes from the dummy fixture values above.
        env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": sandbox, "LC_ALL": "C", "TMPDIR": sandbox}
        proc = subprocess.run(["bash", "-c", script], cwd=sandbox, capture_output=True, text=True,
                              stdin=subprocess.DEVNULL, timeout=120, env=env)
        if proc.returncode != 0:
            raise RuntimeError(f"task '{task}' exited {proc.returncode}:\n{proc.stdout[-2000:]}\n{proc.stderr[-2000:]}")

    out = sb(render["output"])
    if not os.path.isfile(out):
        raise RuntimeError(f"recipe did not write {render['output']}")
    with open(out) as f:
        return yaml.safe_load(f)


# ---------------------------------------------------------------------------
# Config comparison
# ---------------------------------------------------------------------------

COMPONENT_SECTIONS = ("receivers", "processors", "exporters", "extensions", "connectors")


def canonical_name(name, rules):
    for pattern, replacement in rules:
        if re.fullmatch(pattern, name):
            return re.sub(pattern, replacement, name)
    return name


def strip_paths(node, ignore, prefix=""):
    if isinstance(node, dict):
        out = {}
        for k, v in node.items():
            path = f"{prefix}.{k}" if prefix else str(k)
            if any(fnmatch.fnmatchcase(path, pat) for pat in ignore):
                continue
            out[k] = strip_paths(v, ignore, path)
        return out
    if isinstance(node, list):
        return [strip_paths(v, ignore, f"{prefix}[]") for v in node]
    return node


def canonicalize_config(cfg, rules, ignore):
    """Collapse per-instance component names (nroracledb/2 -> nroracledb) into variant lists."""
    cfg = copy.deepcopy(cfg or {})
    canon = {}
    for section in COMPONENT_SECTIONS:
        for name, body in (cfg.get(section) or {}).items():
            cname = canonical_name(name, rules)
            body = strip_paths(body if body is not None else {}, ignore, f"{section}.{cname}")
            variants = canon.setdefault(f"{section}.{cname}", [])
            if body not in variants:
                variants.append(body)
    service = cfg.get("service") or {}
    for name, pipe in (service.get("pipelines") or {}).items():
        cname = canonical_name(name, rules)
        # One shared pipeline listing every receiver and one pipeline per receiver are
        # equivalent, so drop duplicates left behind by canonicalisation.
        body = {k: list(dict.fromkeys(canonical_name(x, rules) for x in (v or []))) for k, v in (pipe or {}).items()}
        variants = canon.setdefault(f"service.pipelines.{cname}", [])
        if body not in variants:
            variants.append(body)
    for key, value in service.items():
        if key != "pipelines":
            canon[f"service.{key}"] = [strip_paths(value, ignore, f"service.{key}")]
    return canon


def deep_diff(doc, rec, path):
    if isinstance(doc, dict) and isinstance(rec, dict):
        out = []
        for k in doc:
            if k not in rec:
                out.append(("missing_in_recipe", f"{path}.{k}", doc[k], None))
            else:
                out.extend(deep_diff(doc[k], rec[k], f"{path}.{k}"))
        for k in rec:
            if k not in doc:
                out.append(("extra_in_recipe", f"{path}.{k}", None, rec[k]))
        return out
    if _norm_scalar(doc) != _norm_scalar(rec):
        return [("value_differs", path, doc, rec)]
    return []


def _norm_scalar(v):
    # `enabled: true` vs `enabled: "true"` and similar are the same to the collector.
    if isinstance(v, bool):
        return str(v).lower()
    if isinstance(v, (int, float)):
        return str(v)
    return v


def compare_configs(doc_cfg, rec_cfg, rules, ignore, only_sections=None):
    doc_c = canonicalize_config(doc_cfg, rules, ignore)
    rec_c = canonicalize_config(rec_cfg, rules, ignore)
    findings = []
    keys = list(doc_c) + [k for k in rec_c if k not in doc_c]
    for key in keys:
        if only_sections and not any(key.startswith(s) for s in only_sections):
            continue
        if key not in rec_c:
            findings.append(("missing_in_recipe", key, doc_c[key][0], None))
            continue
        if key not in doc_c:
            findings.append(("extra_in_recipe", key, None, rec_c[key][0]))
            continue
        for rec_variant in rec_c[key]:
            best = min((deep_diff(d, rec_variant, key) for d in doc_c[key]), key=len)
            for f in best:
                if f not in findings:
                    findings.append(f)
    return findings


# ---------------------------------------------------------------------------
# Link checking
# ---------------------------------------------------------------------------

DOC_URL = re.compile(r"https://docs\.newrelic\.com/docs/([A-Za-z0-9_\-/]+?)/?(?:#([A-Za-z0-9_\-]+))?(?=[\s\"'`)\].,]|$)")


def build_redirect_index(docs_root):
    index = {}
    for dirpath, _, files in os.walk(docs_root):
        for name in files:
            if not name.endswith((".mdx", ".md")):
                continue
            path = os.path.join(dirpath, name)
            with open(path, encoding="utf-8") as f:
                head = f.read(4000)
            fm = re.match(r"---\n(.*?)\n---", head, re.S)
            if not fm:
                continue
            try:
                meta = yaml.safe_load(fm.group(1)) or {}
            except yaml.YAMLError:
                continue
            page = os.path.relpath(path, docs_root).rsplit(".", 1)[0]
            for r in meta.get("redirects") or []:
                index[str(r).strip("/").removeprefix("docs/")] = page
    return index


def check_links(recipe_dir, docs_root, checked_prefixes):
    redirects = build_redirect_index(docs_root)
    findings = []
    seen = set()
    for name in sorted(os.listdir(recipe_dir)):
        path = os.path.join(recipe_dir, name)
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                for m in DOC_URL.finditer(line):
                    page, anchor = m.group(1).strip("/"), m.group(2)
                    if not any(page.startswith(p) for p in checked_prefixes):
                        continue
                    key = (name, page, anchor)
                    if key in seen:
                        continue
                    seen.add(key)
                    loc = f"{name}:{lineno}"
                    url = m.group(0)
                    try:
                        mdx = read_doc(docs_root, page)
                        target = page
                    except FileNotFoundError:
                        target = redirects.get(page)
                        if not target:
                            findings.append({"location": loc, "url": url, "problem": "page not found in docs"})
                            continue
                        findings.append({"location": loc, "url": url,
                                         "problem": f"redirects to /docs/{target}/ - link the new page directly"})
                        mdx = read_doc(docs_root, target)
                    if anchor and not re.search(r"\[#" + re.escape(anchor) + r"\]|\bid=\"" + re.escape(anchor) + "\"", mdx):
                        findings.append({"location": loc, "url": url,
                                         "problem": f"anchor #{anchor} does not exist on /docs/{target}/"})
    return findings


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

def load_accepted(path):
    if not os.path.isfile(path):
        return []
    with open(path) as f:
        return (yaml.safe_load(f) or {}).get("accepted") or []


def match_accepted(accepted, product, scenario, path):
    for a in accepted:
        if (fnmatch.fnmatchcase(product, a.get("product", "*"))
                and fnmatch.fnmatchcase(scenario, a.get("scenario", "*"))
                and fnmatch.fnmatchcase(path, a["path"])):
            return a.get("reason", "accepted")
    return None


def short(v, limit=160):
    s = json.dumps(v, default=str) if not isinstance(v, str) else v
    return s if len(s) <= limit else s[: limit - 3] + "..."


def run(args):
    with open(args.manifest) as f:
        manifest = yaml.safe_load(f)
    accepted = load_accepted(args.accepted)
    docs_root = os.path.join(args.docs_repo, manifest.get("docs_content_root", "src/content/docs"))
    results = {"docs_commit": args.docs_commit, "products": {}}

    for product, spec in manifest["products"].items():
        if args.product and product not in args.product:
            continue
        recipe_dir = os.path.join(REPO_ROOT, spec["recipe_dir"])
        pres = {"grants": [], "configs": [], "links": [], "errors": []}
        results["products"][product] = pres

        for g in spec.get("grants", []):
            try:
                doc_text = "".join(doc_section(read_doc(docs_root, g["doc"]["page"]), s)
                                   for s in g["doc"]["sections"])
                doc_stmts = set().union(*(sql_statements(b) for b in doc_code_blocks(doc_text, {"sql", ""})))
                if not doc_stmts:
                    raise LookupError("no SQL privilege statements found in doc section(s)")
                for rf in g["recipe"]["files"]:
                    rec_stmts = recipe_statements(load_recipe(os.path.join(recipe_dir, rf)), g["recipe"])
                    for kind, items in (("missing_in_recipe", doc_stmts - rec_stmts),
                                        ("extra_in_recipe", rec_stmts - doc_stmts)):
                        for s in sorted(items):
                            text = fmt_stmt(s)
                            pres["grants"].append({
                                "scenario": g["name"], "recipe": rf, "kind": kind, "statement": text,
                                "doc": f"{g['doc']['page']}#{','.join(g['doc']['sections'])}",
                                "accepted": match_accepted(accepted, product, g["name"], text)})
            except Exception as e:  # noqa: BLE001 - report every failure, keep going
                pres["errors"].append(f"grants / {g['name']}: {e}")

        for c in spec.get("configs", []):
            try:
                doc_cfg = doc_config_yaml(doc_section(read_doc(docs_root, c["doc"]["page"]),
                                                      c["doc"].get("section"), c["doc"].get("collapser")))
                render = spec["render"][c["render"]]
                rules = [tuple(r) for r in spec.get("canonical_names", [])]
                ignore = spec.get("ignore_paths", []) + c.get("ignore_paths", [])
                for rf in render["files"]:
                    with tempfile.TemporaryDirectory(prefix="drift-") as sandbox:
                        scenario = copy.deepcopy(manifest["fixtures"][c["fixture"]])
                        for inst in scenario["instances"]:
                            for k, v in list(inst.items()):
                                if isinstance(v, str):
                                    inst[k] = v.replace("{sandbox}", sandbox)
                        scenario["vars"] = c.get("vars", {})
                        rec_cfg = render_recipe_config(load_recipe(os.path.join(recipe_dir, rf)), render,
                                                       scenario, sandbox)
                    for kind, path, dv, rv in compare_configs(doc_cfg, rec_cfg, rules, ignore, c.get("only_sections")):
                        pres["configs"].append({
                            "scenario": c["name"], "recipe": rf, "kind": kind, "path": path,
                            "doc_value": dv, "recipe_value": rv,
                            "doc": f"{c['doc']['page']}#{c['doc'].get('collapser') or c['doc'].get('section')}",
                            "accepted": match_accepted(accepted, product, c["name"], path)})
            except Exception as e:  # noqa: BLE001
                pres["errors"].append(f"config / {c['name']}: {e}")

        try:
            for link in check_links(recipe_dir, docs_root, spec.get("link_prefixes", ["opentelemetry/"])):
                link["accepted"] = match_accepted(accepted, product, "links", link["url"])
                pres["links"].append(link)
        except Exception as e:  # noqa: BLE001
            pres["errors"].append(f"links: {e}")

    return results


def dedupe_recipe_files(rows, key_fields):
    """Merge identical findings that only differ by recipe file (rds-debian/rds-rhel)."""
    merged = {}
    for r in rows:
        key = tuple(json.dumps(r.get(k), sort_keys=True, default=str) for k in key_fields)
        if key in merged:
            merged[key]["recipe"] += f", {r['recipe']}"
        else:
            merged[key] = dict(r)
    return list(merged.values())


def to_markdown(results, docs_repo_url):
    out = ["# NRDOT recipe ↔ docs drift report", ""]
    sha = results.get("docs_commit")
    if sha:
        out.append(f"Compared against [`newrelic/docs-website@{sha[:10]}`]({docs_repo_url}/tree/{sha}).")
        out.append("")
    total = 0
    for product, p in results["products"].items():
        grants = dedupe_recipe_files(p["grants"], ("scenario", "kind", "statement", "accepted"))
        configs = dedupe_recipe_files(p["configs"], ("scenario", "kind", "path", "doc_value", "recipe_value", "accepted"))
        active = [x for x in grants + configs + p["links"] if not x.get("accepted")]
        total += len(active) + len(p["errors"])
        out.append(f"## {product}")
        out.append("")
        out.append(f"**{len(active)} drift finding(s)**, {len(p['errors'])} check error(s), "
                   f"{sum(1 for x in grants + configs + p['links'] if x.get('accepted'))} accepted deviation(s).")
        out.append("")
        if p["errors"]:
            out.append("### ⚠️ Checks that could not run")
            out.append("")
            out.extend(f"- {e.splitlines()[0]}" for e in p["errors"])
            out.append("")
        g_active = [g for g in grants if not g["accepted"]]
        if g_active:
            out.append("### Grants")
            out.append("")
            out.append("| Scenario | Recipe | Change | Statement | Doc source |")
            out.append("|---|---|---|---|---|")
            for g in g_active:
                change = "➕ add (in docs, not recipe)" if g["kind"] == "missing_in_recipe" else "➖ remove? (recipe only)"
                out.append(f"| {g['scenario']} | `{g['recipe']}` | {change} | `{g['statement']}` | `{g['doc']}` |")
            out.append("")
        c_active = [c for c in configs if not c["accepted"]]
        if c_active:
            out.append("### Collector config")
            out.append("")
            out.append("| Scenario | Recipe | Path | Docs | Recipe | Doc source |")
            out.append("|---|---|---|---|---|---|")
            for c in c_active:
                dv = "—" if c["kind"] == "extra_in_recipe" else f"`{short(c['doc_value'])}`"
                rv = "—" if c["kind"] == "missing_in_recipe" else f"`{short(c['recipe_value'])}`"
                out.append(f"| {c['scenario']} | `{c['recipe']}` | `{c['path']}` | {dv} | {rv} | `{c['doc']}` |")
            out.append("")
        l_active = [lk for lk in p["links"] if not lk["accepted"]]
        if l_active:
            out.append("### Doc links")
            out.append("")
            out.extend(f"- `{lk['location']}` {lk['url']} — {lk['problem']}" for lk in l_active)
            out.append("")
        acc = [x for x in grants + configs + p["links"] if x.get("accepted")]
        if acc:
            out.append("<details><summary>Accepted deviations (see accepted-deviations.yml)</summary>")
            out.append("")
            for x in acc:
                what = x.get("statement") or x.get("path") or x.get("url")
                out.append(f"- {x.get('scenario', 'links')}: `{what}` — {x['accepted']}")
            out.append("")
            out.append("</details>")
            out.append("")
    results["drift_count"] = total
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--docs-repo", required=True, help="path to a checkout of newrelic/docs-website")
    ap.add_argument("--docs-commit", default=None, help="docs-website commit SHA, for the report")
    ap.add_argument("--manifest", default=os.path.join(HERE, "manifest.yml"))
    ap.add_argument("--accepted", default=os.path.join(HERE, "accepted-deviations.yml"))
    ap.add_argument("--product", action="append", help="limit to product(s) in manifest, e.g. oracle")
    ap.add_argument("--report", default="drift-report.md")
    ap.add_argument("--json", default="drift-report.json")
    ap.add_argument("--fail-on-drift", action="store_true")
    args = ap.parse_args()

    if not args.docs_commit:
        try:
            args.docs_commit = subprocess.run(["git", "-C", args.docs_repo, "rev-parse", "HEAD"],
                                              capture_output=True, text=True, check=True).stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass

    results = run(args)
    report = to_markdown(results, "https://github.com/newrelic/docs-website")
    with open(args.report, "w") as f:
        f.write(report + "\n")
    with open(args.json, "w") as f:
        json.dump(results, f, indent=2, default=str)
    print(report)

    gh_out = os.environ.get("GITHUB_OUTPUT")
    if gh_out:
        with open(gh_out, "a") as f:
            f.write(f"drift_count={results['drift_count']}\n")
            f.write(f"docs_commit={results.get('docs_commit') or ''}\n")
    if args.fail_on_drift and results["drift_count"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
