"""DS, Parts A1 and C: groups in hosts.ini; shopfront_color in group_vars and host_vars."""
import json
import os
import subprocess
import sys

import yaml

os.chdir(os.path.join(os.path.dirname(__file__), ".."))
errors = []


def inv(*args, inventory="inventory/hosts.ini"):
    out = subprocess.run(["ansible-inventory", "-i", inventory, *args],
                         capture_output=True, text=True)
    if out.returncode != 0:
        print(out.stderr)
        sys.exit(f"FAIL: ansible-inventory failed on {inventory}")
    return json.loads(out.stdout)


# A1: the groups, from the student's own hosts.ini
data = inv("--list")
def hosts(group):
    return sorted(data.get(group, {}).get("hosts", []))
if hosts("app") != ["app1", "app2"]:
    errors.append(f"group app must hold app1 and app2, got {hosts('app')}")
if hosts("lb") != ["lb1"]:
    errors.append(f"group lb must hold lb1, got {hosts('lb')}")
children = sorted(data.get("shop", {}).get("children", []))
if children != ["app", "lb"]:
    errors.append(f"group shop must have the children app and lb, got {children}")
hv = data.get("_meta", {}).get("hostvars", {})
for h in ("app1", "app2", "lb1"):
    if hv.get(h, {}).get("internal_address") != h:
        errors.append(f"{h} must keep internal_address={h} from inventory/generated.ini")

# C: colour precedence (role default < group app < host app2)
default = None
try:
    with open("roles/shopfront/defaults/main.yml") as f:
        default = (yaml.safe_load(f) or {}).get("shopfront_color")
except FileNotFoundError:
    pass
try:
    with open("inventory/group_vars/app/vars.yml") as f:
        group = (yaml.safe_load(f) or {}).get("shopfront_color")
except FileNotFoundError:
    group = None
app2_file = {}
if os.path.exists("inventory/host_vars/app2.yml"):
    with open("inventory/host_vars/app2.yml") as f:
        app2_file = yaml.safe_load(f) or {}
app1_defines = False
for name in ("app1.yml", "app1.yaml", "app1"):
    p = os.path.join("inventory/host_vars", name)
    if os.path.isfile(p):
        with open(p) as f:
            app1_defines = "shopfront_color" in (yaml.safe_load(f) or {})

if not group:
    errors.append("group_vars/app/vars.yml must define shopfront_color")
if not app2_file.get("shopfront_color"):
    errors.append("host_vars/app2.yml must define shopfront_color")
elif app2_file["shopfront_color"] == group:
    errors.append("app2's shopfront_color must differ from the group value")
if app1_defines:
    errors.append("app1 must not set shopfront_color in host_vars: it keeps the group value")
if default and default in (group, app2_file.get("shopfront_color")):
    errors.append("the group and app2 colours must differ from the role default")

if errors:
    print("\n".join("FAIL: " + e for e in errors))
    sys.exit(1)
print("OK: groups app, lb and shop; colours set per group and per host")
