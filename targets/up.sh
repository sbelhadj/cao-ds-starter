#!/usr/bin/env bash
# DS: start the three servers of SESAME Shop as containers in your Codespace.
#
#   lb1   load balancer   ssh localhost:2200   http localhost:8080 (its port 80)
#   app1  shop front      ssh localhost:2201   http localhost:8081 (its port 8080)
#   app2  shop front      ssh localhost:2202   http localhost:8082 (its port 8080)
#
# The three share the Docker network cao-ds-net, where each one is reached
# by its name: that name is its internal_address.
#
# Writes inventory/generated.ini. Safe to re-run: existing servers are replaced,
# which gives you three fresh servers.
set -euo pipefail
cd "$(dirname "$0")/.."

KEY="${KEY:-$HOME/.ssh/cao_lab}"
IMAGE="cao-ds-node"
NET="cao-ds-net"

if [[ ! -f "$KEY" ]]; then
  mkdir -p "$(dirname "$KEY")"
  ssh-keygen -q -t ed25519 -N "" -f "$KEY"
  echo "Created SSH key $KEY"
fi

# EXTRA_PUBKEY: one more key allowed to log in (the autograder adds yours, so
# that you can keep working on the servers after "make test").
PUBKEYS="$(cat "$KEY.pub")"
[[ -n "${EXTRA_PUBKEY:-}" ]] && PUBKEYS+=$'\n'"$EXTRA_PUBKEY"

echo "==> Building the server image (first time: about one minute)"
docker build -q -t "$IMAGE" --build-arg PUBKEY="$PUBKEYS" targets/node >/dev/null

docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >/dev/null

start() { # name ssh_port host_http_port container_http_port
  docker rm -f "$1" >/dev/null 2>&1 || true
  docker run -d --name "$1" --hostname "$1" --network "$NET" \
    -p "$2:22" -p "$3:$4" "$IMAGE" >/dev/null
  echo "$1 started (ssh localhost:$2, http localhost:$3)"
}

echo "==> Starting the servers"
start lb1  2200 8080 80
start app1 2201 8081 8080
start app2 2202 8082 8080

cat > inventory/generated.ini <<INI
# Written by targets/up.sh. Copy these lines into inventory/hosts.ini.
lb1 ansible_host=127.0.0.1 ansible_port=2200 internal_address=lb1
app1 ansible_host=127.0.0.1 ansible_port=2201 internal_address=app1
app2 ansible_host=127.0.0.1 ansible_port=2202 internal_address=app2
INI

for p in 2200 2201 2202; do
  for _ in $(seq 1 30); do
    ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=2 -i "$KEY" -p "$p" azureuser@127.0.0.1 true && break
    sleep 1
  done
done
echo "==> Done. Connection details are in inventory/generated.ini"
