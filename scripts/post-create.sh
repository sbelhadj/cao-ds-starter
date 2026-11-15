#!/usr/bin/env bash
# Runs once when the Codespace is created. Installs the DS toolbox.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Installing Ansible and ansible-lint (pinned, same as the autograder)"
python3 -m pip install --user --quiet --no-cache-dir -r tests/requirements.txt
grep -q '.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

chmod +x scripts/*.sh targets/*.sh tests/*.sh

if [[ ! -f ~/.ssh/cao_lab ]]; then
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/cao_lab
fi

echo "==> Toolbox ready. Run: make check"
