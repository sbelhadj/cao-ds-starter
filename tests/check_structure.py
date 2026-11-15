"""DS, Parts B to D: roles and playbook have the expected shape."""
import glob
import os
import sys

import yaml

os.chdir(os.path.join(os.path.dirname(__file__), ".."))
errors = []


def load(path):
    try:
        with open(path) as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        errors.append(f"{path} is missing")
    except yaml.YAMLError as e:
        errors.append(f"{path} is not valid YAML: {e}")
    return None


for role in ("common", "shopfront", "loadbalancer"):
    base = f"roles/{role}"
    for sub in ("tasks", "handlers", "defaults", "meta"):
        p = f"{base}/{sub}/main.yml"
        if not os.path.isfile(p):
            errors.append(f"{p} is missing")
    if not glob.glob(f"{base}/templates/*.j2"):
        errors.append(f"{base}/templates/ needs at least one .j2 template")
    meta = load(f"{base}/meta/main.yml") if os.path.isfile(f"{base}/meta/main.yml") else None
    if isinstance(meta, dict):
        name = (meta.get("galaxy_info") or {}).get("role_name")
        if name != role:
            errors.append(f"{base}/meta/main.yml: role_name must be {role}, got {name!r}")
    handlers = load(f"{base}/handlers/main.yml") if os.path.isfile(f"{base}/handlers/main.yml") else None
    if role != "common" and not handlers:
        errors.append(f"{base}/handlers/main.yml defines no handler")
    tasks_text = ""
    for p in glob.glob(f"{base}/tasks/*.yml"):
        with open(p) as f:
            tasks_text += f.read()
    if role != "common" and "notify:" not in tasks_text:
        errors.append(f"{base}: no task notifies a handler")

plays = load("playbooks/site.yml")
expected = [("shop", "common"), ("app", "shopfront"), ("lb", "loadbalancer")]
if not isinstance(plays, list) or len(plays) != 3:
    errors.append("playbooks/site.yml must hold exactly three plays")
else:
    for i, (play, (hosts, role)) in enumerate(zip(plays, expected), 1):
        if not isinstance(play, dict):
            errors.append(f"play {i} is not a mapping")
            continue
        if play.get("hosts") != hosts:
            errors.append(f"play {i} must target hosts: {hosts}, got {play.get('hosts')!r}")
        roles = [r if isinstance(r, str) else (r or {}).get("role", (r or {}).get("name"))
                 for r in (play.get("roles") or [])]
        if role not in roles:
            errors.append(f"play {i} must use the role {role}")
        if play.get("become") is not True:
            errors.append(f"play {i} needs become: true")
    if isinstance(plays[1], dict):
        vf = plays[1].get("vars_files") or []
        if not any(str(v).endswith("data/catalog.yml") for v in vf):
            errors.append("play 2 must load ../data/catalog.yml with vars_files")

if errors:
    print("\n".join("FAIL: " + e for e in errors))
    sys.exit(1)
print("OK: three roles and three plays, in the expected shape")
