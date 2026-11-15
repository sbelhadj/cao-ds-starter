#!/usr/bin/env bash
# DS: remove the three servers and their network.
set -uo pipefail
cd "$(dirname "$0")/.."
docker rm -f lb1 app1 app2 >/dev/null 2>&1
docker network rm cao-ds-net >/dev/null 2>&1
rm -f inventory/generated.ini
echo "Servers removed."
