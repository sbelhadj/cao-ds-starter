#!/usr/bin/env bash
# How SESAME Shop servers were prepared before Ansible: an operator ran this
# script by hand, once, as root, on every new server.
#
# Reference only: do NOT run it. The role roles/common was translated from it.
# Part B asks you to fix that role so that it reaches the same result,
# the declarative way.

apt-get update
apt-get install -y nginx tree jq

useradd --create-home --shell /bin/bash deploy
useradd --create-home --shell /usr/sbin/nologin monitor

echo "SESAME Shop - managed by Ansible. Do not edit by hand." > /etc/motd

mkdir /opt/shop
chown deploy /opt/shop
chmod 755 /opt/shop

service nginx start

cat > /etc/nginx/conf.d/00-security.conf <<'EOF'
server_tokens off;
add_header X-Content-Type-Options nosniff always;
EOF
service nginx reload

echo "Kernel: $(uname -r)"
