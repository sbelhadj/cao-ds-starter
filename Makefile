.PHONY: help check up down ping run lint vault-pass test-yaml test-inventory test-common test clean

export PATH := $(HOME)/.local/bin:$(PATH)
VAULT_PASS_FILE ?= $(HOME)/.cao_ds_vault_pass

help:
	@echo "make check           verify the toolbox"
	@echo "make up              start lb1, app1, app2 (fresh servers every time)"
	@echo "make ping            ansible shop -m ping"
	@echo "make run             run playbooks/site.yml (extra options: ARGS=\"-e x=y\")"
	@echo "make lint            ansible-lint, moderate profile, as the autograder"
	@echo "make vault-pass      Part E: write the DS vault password to ~/.cao_ds_vault_pass"
	@echo "make test-yaml       Part A2 check"
	@echo "make test-inventory  Parts A1 and C colours check"
	@echo "make test-common     Part B check (on your current servers)"
	@echo "make test            every autograder check, on fresh servers (about 4 minutes)"
	@echo "make down            remove the servers"

check:
	@bash scripts/check.sh

up:
	@bash targets/up.sh

down:
	@bash targets/down.sh

ping:
	ansible shop -m ansible.builtin.ping

run:
	ansible-playbook playbooks/site.yml $(ARGS)

lint:
	ansible-lint -c tests/ansible-lint.yml

vault-pass:
	@umask 077; printf '%s\n' "sesame-cao-ds" > $(VAULT_PASS_FILE)
	@echo "Wrote $(VAULT_PASS_FILE) (mode 600). DS password only: never do this with a real one."

test-yaml:
	@python3 tests/check_yaml.py

test-inventory:
	@python3 tests/check_inventory.py

test-common:
	@bash tests/grade.sh common

# Same checks as the autograder, on fresh local servers.
# This replaces your lb1, app1 and app2: your playbook rebuilds them.
test:
	@bash tests/ci-targets.sh
	@for c in yaml inventory common structure first-run app lb idempotent drift vault answers; do \
	  echo; echo "===== $$c"; bash tests/grade.sh $$c; \
	done; $(MAKE) --no-print-directory clean
	@echo; echo "Your servers were replaced by the test ones, configured by your playbook. make run works as usual; make up gives blank ones."

clean:
	@if [ -f .ci/vault.yml.unreadable ]; then mv .ci/vault.yml.unreadable inventory/group_vars/app/vault.yml; fi
	@rm -rf inventory/ci.ini .ci_key .ci_key.pub .ci_vault_pass .ci playbooks/.grader-site.yml
