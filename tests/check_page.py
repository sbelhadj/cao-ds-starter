"""DS, Part C: the shop page of one host matches the catalog. Page on stdin.

usage: check_page.py HOST COLOR
The expected values are read from YOUR data/catalog.yml, so a wrong catalog
value is only counted once, in the YAML check.
"""
import html
import os
import sys

import yaml

host, color = sys.argv[1], sys.argv[2]
page = sys.stdin.read()
lines = [l.strip() for l in page.splitlines()]
os.chdir(os.path.join(os.path.dirname(__file__), ".."))
with open("data/catalog.yml") as f:
    cat = yaml.safe_load(f)

def j(v):  # how Jinja2 prints a scalar
    return str(v)

want = [
    f"<title>{j(cat['shop_name'])}</title>",
    f"<h1>{j(cat['shop_name'])}</h1>",
    f"<p>{j(cat['tagline'])}</p>",
    f"<p>Served by {host}</p>",
    "<p>Running Ubuntu 24.04</p>",
    f"<p>Ships to: {', '.join(j(c) for c in cat['ship_to'])}</p>",
    f"<p>Catalog API {j(cat['api_version'])} - Open until {j(cat['closing_time'])}</p>",
]
errors = []
for w in want:
    if w not in lines and html.escape(w, quote=False) not in lines:
        errors.append(f"missing line: {w}")
if f"background: {color};" not in page:
    errors.append(f"the body background must be this host's shopfront_color ({color})")

items = [l for l in lines if l.startswith("<li>")]
expected_items = []
for p in cat["products"]:
    avail = "in stock" if p["stock"] > 0 else "sold out"
    expected_items.append(f"<li>{j(p['name'])} | {j(p['sku'])} | {p['price']:.3f} TND | {avail}</li>")
if items != expected_items:
    errors.append("catalog lines differ.\n  expected:\n    " + "\n    ".join(expected_items)
                  + "\n  got:\n    " + ("\n    ".join(items) or "(no <li> line)"))
if "TODO" in page:
    errors.append("the page still contains TODO")

if errors:
    print("\n".join(f"FAIL ({host}): " + e for e in errors))
    sys.exit(1)
print(f"OK: the page of {host} is right")
