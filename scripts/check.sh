#!/usr/bin/env bash
# make check: is the DS toolbox working?
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
fail=0
line() { printf '  [%-4s] %-14s %s\n' "$1" "$2" "$3"; }
tool() { # name command
  if v=$(eval "$2" 2>/dev/null | head -1) && [[ -n $v ]]; then line " OK " "$1" "$v"
  else line FAIL "$1" "not found: run bash scripts/post-create.sh"; fail=1; fi
}
echo "Tools"
tool git            "git --version"
tool python3        "python3 --version"
tool ansible        "ansible --version | head -1"
tool ansible-lint   "ansible-lint --version | head -1 | cut -d' ' -f1-2"
tool docker         "docker version --format 'Docker {{.Server.Version}}'"
tool pyyaml         "python3 -c 'import yaml; print(\"PyYAML\", yaml.__version__)'"
echo "Git identity"
n=$(git config user.name); e=$(git config user.email)
if [[ -n $n && -n $e ]]; then line " OK " "git user" "$n <$e>"
else line FAIL "git user" 'git config --global user.name "..." and user.email "..."'; fail=1; fi
echo "SSH key"
if [[ -f ~/.ssh/cao_lab ]]; then line " OK " "~/.ssh/cao_lab" "present"
else line FAIL "~/.ssh/cao_lab" "missing: run bash scripts/post-create.sh"; fail=1; fi
echo
if [[ $fail == 0 ]]; then echo "Environment ready."; else echo "Fix the FAIL lines above."; exit 1; fi
