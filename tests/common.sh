# Shared settings for the DS checks. Sourced, not run.
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export PATH="$HOME/.local/bin:$PATH"
export ANSIBLE_FORCE_COLOR=0 ANSIBLE_NOCOLOR=1
if [[ -f inventory/ci.ini ]]; then INV="inventory/ci.ini"; else INV="inventory/hosts.ini"; fi
# The CI vault password file wins over the line in ansible.cfg
# (the runner has no ~/.cao_ds_vault_pass).
if [[ -f .ci_vault_pass ]]; then export ANSIBLE_VAULT_PASSWORD_FILE="$PWD/.ci_vault_pass"; fi
mkdir -p .ci
play() { ansible-playbook -i "$INV" playbooks/site.yml "$@"; }
recap_clean() { # stdin: playbook output; true if no host changed or failed
  sed -n '/PLAY RECAP/,$p' | tee /dev/stderr | grep -Eq 'changed=[1-9]|failed=[1-9]|unreachable=[1-9]' && return 1 || return 0
}
