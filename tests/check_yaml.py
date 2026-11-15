"""DS, Part A2: data/catalog.yml loads with exactly the values the team meant."""
import os
import sys

import yaml

os.chdir(os.path.join(os.path.dirname(__file__), ".."))

EXPECTED = {
    "shop_name": "SESAME Shop",
    "tagline": "Shop smart: pay less",
    "api_version": "1.10",
    "closing_time": "22:30",
    "ship_to": ["TN", "DZ", "NO", "FR"],
    "products": [
        {"name": "Laptop ThinkPad E14", "sku": "004517", "price": 2499.0, "stock": 12},
        {"name": "Cable USB-C #2", "sku": "120034", "price": 19.5, "stock": 140},
        {"name": "Headset Jabra Evolve2", "sku": "310007", "price": 349.9, "stock": 0},
        {"name": "Mouse Logitech M185", "sku": "205561", "price": 45.0, "stock": 37},
    ],
}


def same(a, b):
    """Equal values AND equal types (True is not 1, 1.1 is not "1.10")."""
    if type(a) is not type(b):
        return False
    if isinstance(a, dict):
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    return a == b


try:
    with open("data/catalog.yml") as f:
        data = yaml.safe_load(f)
except yaml.YAMLError as e:
    sys.exit(f"FAIL: data/catalog.yml does not load:\n{e}")

if not isinstance(data, dict):
    sys.exit("FAIL: data/catalog.yml must be a mapping")

errors = []
for key, want in EXPECTED.items():
    got = data.get(key, "<missing>")
    if not same(got, want):
        errors.append(f"{key}: got {got!r}, expected {want!r}")
extra = set(data) - set(EXPECTED)
if extra:
    errors.append(f"unexpected keys: {sorted(extra)}")

if errors:
    print("\n".join("FAIL: " + e for e in errors))
    sys.exit(1)
print("OK: data/catalog.yml loads with the expected values and types")
