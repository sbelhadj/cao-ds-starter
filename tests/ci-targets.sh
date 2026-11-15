#!/usr/bin/env bash
# Autograder (and "make test"): start three fresh servers and write a CI
# inventory for them. It lives in inventory/ so that your group_vars/ and
# host_vars/ apply to it exactly as they apply to hosts.ini.
# It never reads your hosts.ini: the grader builds its own server list.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .ci

export KEY="$PWD/.ci_key"
rm -f "$KEY" "$KEY.pub"
ssh-keygen -q -t ed25519 -N "" -f "$KEY"
EXTRA_PUBKEY="$(cat "$HOME/.ssh/cao_lab.pub" 2>/dev/null || true)" ./targets/up.sh >/dev/null

cat > inventory/ci.ini <<INI
[app]
app1 ansible_host=127.0.0.1 ansible_port=2201 internal_address=app1 ansible_ssh_private_key_file=$KEY
app2 ansible_host=127.0.0.1 ansible_port=2202 internal_address=app2 ansible_ssh_private_key_file=$KEY

[lb]
lb1 ansible_host=127.0.0.1 ansible_port=2200 internal_address=lb1 ansible_ssh_private_key_file=$KEY

[shop:children]
app
lb
INI

# The DS vault password (see the statement, Part E). Exam only: a real vault
# password comes from a secret store, never from a file in Git.
printf '%s\n' "sesame-cao-ds" > .ci_vault_pass
chmod 600 .ci_vault_pass

# A vault file the grader cannot open would make every run fail. Set it aside
# so that the other checks still run; the Vault check then fails on its own.
vf=inventory/group_vars/app/vault.yml
if [[ -f $vf ]] && ! ansible-vault view --vault-password-file .ci_vault_pass "$vf" >/dev/null 2>&1; then
  mv "$vf" .ci/vault.yml.unreadable
  echo "WARNING: $vf cannot be decrypted with the DS vault password; set aside for this run."
fi
echo "CI targets ready."
