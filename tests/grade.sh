#!/usr/bin/env bash
# DS autograder. Each mode is one graded check of .github/workflows/classroom.yml.
# "make test" runs them all, in the same order, on fresh local servers.
#
#   yaml        A2  data/catalog.yml has the expected values and types      2
#   inventory   A1  groups app, lb, shop; colours in group_vars/host_vars   1
#   common      B   role common alone: converges, then a clean second run   3
#   structure   C,D roles and plays in shape, ansible-lint clean            2
#   first-run       (not graded) first run of playbooks/site.yml
#   app         C   both shop pages, health pages, nginx on the shop port   3
#   lb          D   lb1 balances over app1 and app2, from the inventory     2
#   idempotent      second run of site.yml: changed=0, still right          2
#   drift       C,D hand edits reverted with handlers; maintenance switch   2
#   vault       E   secret encrypted, delivered with mode 600, no_log       2
#   answers         ANSWERS.md complete                                     1
set -uo pipefail
source "$(dirname "$0")/common.sh"
mode="${1:-}"

hv() { # hv HOST VAR: one host variable as the inventory resolves it
  ansible-inventory -i "$INV" --host "$1" 2>/dev/null \
    | python3 -c 'import json,sys; v=json.load(sys.stdin).get(sys.argv[1]); print("" if v is None else v)' "$2"
}
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$1"; }

# playbooks/.grader-site.yml: your site.yml without the play(s) of the role common.
# Used so that a broken Part B does not cost the points of Parts C and D.
SITE_NO_COMMON=playbooks/.grader-site.yml
make_site_without_common() {
  python3 - "$SITE_NO_COMMON" <<'PY'
import sys, yaml
try:
    plays = yaml.safe_load(open("playbooks/site.yml"))
except Exception:
    sys.exit(1)
if not isinstance(plays, list):
    sys.exit(1)
def uses_common(p):
    roles = (p or {}).get("roles") or []
    return any((r if isinstance(r, str) else (r or {}).get("role")) == "common" for r in roles)
keep = [p for p in plays if isinstance(p, dict) and not uses_common(p)]
if not keep:
    sys.exit(1)
with open(sys.argv[1], "w") as f:
    yaml.safe_dump(keep, f, sort_keys=False)
PY
}

check_app() {
  local ok=0 i color p
  for i in 1 2; do
    color=$(hv "app$i" shopfront_color)
    p=$(curl -fsS --max-time 5 "http://127.0.0.1:808$i/") \
      || { echo "FAIL: app$i answers nothing on its port 8080: nginx must listen on shopfront_port, wired to 8080 in group_vars/all"; ok=1; continue; }
    python3 tests/check_page.py "app$i" "$color" <<<"$p" || ok=1
    [[ $(curl -fsS --max-time 5 "http://127.0.0.1:808$i/health") == "OK app$i" ]] \
      || { echo "FAIL: http://app$i:8080/health must answer exactly: OK app$i"; ok=1; }
    [[ $(code "http://127.0.0.1:808$i/maintenance.html") == 404 ]] \
      || { echo "FAIL: app$i publishes maintenance.html although shop_maintenance is false"; ok=1; }
  done
  return $ok
}

check_lb() {
  local ok=0 conf seen=""
  conf=$(docker exec lb1 cat /etc/nginx/sites-available/default 2>/dev/null)
  for i in 1 2; do
    grep -Eq "^\s*server\s+app$i:8080\s*;" <<<"$conf" \
      || { echo "FAIL: lb1's nginx config has no line 'server app$i:8080;'"; ok=1; }
  done
  if ! grep -lqE "groups\[" roles/loadbalancer/templates/*.j2 2>/dev/null \
     || ! grep -lqE "hostvars\[" roles/loadbalancer/templates/*.j2 2>/dev/null; then
    echo "FAIL: the loadbalancer template must build the server list from groups[...] and hostvars[...]"; ok=1
  fi
  for _ in $(seq 1 8); do
    seen+=$(curl -fsS --max-time 5 http://127.0.0.1:8080/ 2>/dev/null | grep -o 'Served by app[12]')$'\n'
  done
  for i in 1 2; do
    grep -q "Served by app$i" <<<"$seen" \
      || { echo "FAIL: http://lb1/ never answered from app$i in 8 requests"; ok=1; }
  done
  return $ok
}

case "$mode" in
  yaml)
    python3 tests/check_yaml.py
    ;;
  inventory)
    python3 tests/check_inventory.py
    ;;
  common)
    out=$(ansible-playbook -i "$INV" tests/common.yml 2>&1) || { echo "$out" | tail -25; echo "FAIL: the role common does not run"; exit 1; }
    out=$(ansible-playbook -i "$INV" tests/common.yml 2>&1) || { echo "$out" | tail -25; echo "FAIL: the second run of the role common fails"; exit 1; }
    echo "$out" | recap_clean || { echo "FAIL: the second run of the role common changed something (see the yellow tasks)"; echo "$out" | grep -B1 '^changed:' | head -20; exit 1; }
    ok=0
    for h in lb1 app1 app2; do
      for pkg in nginx tree jq; do
        docker exec "$h" dpkg -s "$pkg" >/dev/null 2>&1 || { echo "FAIL: $h: package $pkg not installed"; ok=1; }
      done
      [[ $(docker exec "$h" getent passwd deploy | cut -d: -f7) == /bin/bash ]] || { echo "FAIL: $h: user deploy with shell /bin/bash"; ok=1; }
      [[ $(docker exec "$h" getent passwd monitor | cut -d: -f7) == /usr/sbin/nologin ]] || { echo "FAIL: $h: user monitor with shell /usr/sbin/nologin"; ok=1; }
      docker exec "$h" test -d /home/deploy || { echo "FAIL: $h: deploy has no home folder"; ok=1; }
      [[ $(docker exec "$h" cat /etc/motd) == "SESAME Shop - managed by Ansible. Do not edit by hand." ]] || { echo "FAIL: $h: /etc/motd content"; ok=1; }
      [[ $(docker exec "$h" stat -c '%F %U %a' /opt/shop 2>/dev/null) == "directory deploy 755" ]] || { echo "FAIL: $h: /opt/shop must be a folder owned by deploy, mode 0755"; ok=1; }
      docker exec "$h" grep -q 'server_tokens off' /etc/nginx/conf.d/00-security.conf 2>/dev/null || { echo "FAIL: $h: /etc/nginx/conf.d/00-security.conf"; ok=1; }
      hdr=""
      for port in 80 8080; do  # app servers move to 8080 once the role shopfront has run
        hdr=$(docker exec "$h" curl -sI --max-time 5 "http://127.0.0.1:$port/" | tr -d '\r' | grep -i '^server:') && break
      done
      [[ ${hdr,,} == "server: nginx" ]] || { echo "FAIL: $h: nginx must run and hide its version (got '$hdr'): was it reloaded?"; ok=1; }
    done
    [[ $ok == 0 ]] && echo "OK: the role common converges and its second run changes nothing"
    exit $ok
    ;;
  structure)
    python3 tests/check_structure.py || exit 1
    if grep -rnE 'noqa|skip_list|warn_list' roles playbooks inventory 2>/dev/null; then
      echo "FAIL: do not hide ansible-lint findings (noqa, skip_list)"; exit 1
    fi
    ansible-lint -c tests/ansible-lint.yml --nocolor 2>&1 | tail -30
    rc=${PIPESTATUS[0]}
    [[ $rc == 0 ]] || { echo "FAIL: ansible-lint (moderate profile) reports findings"; exit 1; }
    echo "OK: structure and ansible-lint"
    ;;
  first-run)
    play >.ci/first-run.log 2>&1; rc=$?
    sed -n '/PLAY RECAP/,$p' .ci/first-run.log
    if [[ $rc != 0 ]]; then
      grep -E '^(fatal|failed|ERROR)|\[ERROR\]' .ci/first-run.log | head -10
      echo "First run of site.yml failed (rc=$rc)."
      # A broken role common must not hide the work done in Parts C and D:
      # run the shopfront and loadbalancer plays on their own.
      if make_site_without_common; then
        echo "Running the plays of Parts C and D without the role common:"
        ansible-playbook -i "$INV" "$SITE_NO_COMMON" >.ci/first-run-cd.log 2>&1
        sed -n '/PLAY RECAP/,$p' .ci/first-run-cd.log
      fi
    fi
    exit 0
    ;;
  app)
    check_app && echo "OK: both shop servers serve the right page"
    ;;
  lb)
    check_lb && echo "OK: lb1 balances over app1 and app2"
    ;;
  idempotent)
    out=$(play 2>&1) || { echo "$out" | tail -20; echo "FAIL: the second run fails"; exit 1; }
    echo "$out" | recap_clean || { echo "FAIL: the second run changed something: the playbook is not idempotent"; echo "$out" | grep -B1 '^changed:' | head -20; exit 1; }
    for h in lb1 app1 app2; do
      grep -Eq "^$h +: ok=[1-9]" <<<"$out" || { echo "FAIL: the second run did nothing on $h"; exit 1; }
    done
    grep -q 'TASK \[shopfront : ' <<<"$out" && grep -q 'TASK \[loadbalancer : ' <<<"$out" \
      || { echo "FAIL: site.yml must run the roles shopfront and loadbalancer"; exit 1; }
    for i in 1 2; do
      [[ $(code "http://127.0.0.1:808$i/") == 200 ]] || { echo "FAIL: app$i does not serve its page after the second run"; exit 1; }
    done
    echo "OK: second run changed nothing, and the shop still answers"
    ;;
  drift)
    docker exec app1 sh -c 'echo "# hotfix by hand" >> /etc/nginx/sites-available/default'
    docker exec lb1 sh -c 'echo "# hotfix by hand" >> /etc/nginx/sites-available/default'
    docker exec app2 rm -f /var/www/shop/index.html
    # Parts C and D only: the role common is graded in its own check.
    make_site_without_common || { echo "FAIL: playbooks/site.yml cannot be read"; exit 1; }
    cd_play() { ansible-playbook -i "$INV" "$SITE_NO_COMMON" "$@"; }
    out=$(cd_play 2>&1) || { echo "$out" | tail -20; echo "FAIL: the run after the hand edits fails"; exit 1; }
    ok=0
    grep -q 'RUNNING HANDLER \[shopfront : ' <<<"$out" || { echo "FAIL: the changed nginx site on app1 must notify a handler of the role shopfront"; ok=1; }
    grep -q 'RUNNING HANDLER \[loadbalancer : ' <<<"$out" || { echo "FAIL: the changed nginx site on lb1 must notify a handler of the role loadbalancer"; ok=1; }
    for h in app1 lb1; do
      docker exec "$h" grep -q 'hotfix by hand' /etc/nginx/sites-available/default && { echo "FAIL: $h: the hand edit is still there"; ok=1; }
    done
    curl -fsS --max-time 5 http://127.0.0.1:8082/ | grep -q 'Served by app2' || { echo "FAIL: app2's deleted page was not put back"; ok=1; }
    out=$(cd_play -e shop_maintenance=true 2>&1) || { echo "$out" | tail -15; echo "FAIL: run with -e shop_maintenance=true fails"; exit 1; }
    for i in 1 2; do
      [[ $(code "http://127.0.0.1:808$i/maintenance.html") == 200 ]] || { echo "FAIL: shop_maintenance=true must publish maintenance.html on app$i"; ok=1; }
    done
    out=$(cd_play -e shop_maintenance=false 2>&1) || { echo "$out" | grep -E 'fatal|ERROR' | head -5; echo "FAIL: run with -e shop_maintenance=false fails (a value given with -e is a string)"; exit 1; }
    for i in 1 2; do
      [[ $(code "http://127.0.0.1:808$i/maintenance.html") == 404 ]] || { echo "FAIL: shop_maintenance=false must remove maintenance.html from app$i"; ok=1; }
    done
    [[ $ok == 0 ]] && echo "OK: drift fixed with handlers, maintenance switch works both ways"
    exit $ok
    ;;
  vault)
    vf=inventory/group_vars/app/vault.yml
    [[ -f $vf ]] || { echo "FAIL: $vf is missing or cannot be decrypted with the DS vault password"; exit 1; }
    head -1 "$vf" | grep -q '^\$ANSIBLE_VAULT;' || { echo "FAIL: $vf is not encrypted"; exit 1; }
    secret=$(ansible-vault view "$vf" | python3 -c "import yaml,sys; print((yaml.safe_load(sys.stdin) or {}).get('vault_shop_api_key',''))") \
      || { echo "FAIL: cannot decrypt $vf with the DS vault password"; exit 1; }
    [[ ${#secret} -ge 16 && $secret =~ ^[A-Za-z0-9_-]+$ ]] || { echo "FAIL: vault_shop_api_key must be 16+ characters: letters, digits, - and _"; exit 1; }
    grep -Eq '^shopfront_api_key: *"\{\{ *vault_shop_api_key *\}\}" *$' inventory/group_vars/app/vars.yml \
      || { echo 'FAIL: group_vars/app/vars.yml must contain: shopfront_api_key: "{{ vault_shop_api_key }}"'; exit 1; }
    if grep -rlF --exclude=vault.yml --exclude-dir=.git --exclude-dir=.ci -- "$secret" . 2>/dev/null; then
      echo "FAIL: the secret appears in clear text in the file(s) above"; exit 1
    fi
    python3 - <<'PY' || exit 1
import glob, sys, yaml
tasks = []
def walk(items):
    for t in items or []:
        if isinstance(t, dict):
            tasks.append(t)
            for k in ("block", "rescue", "always"):
                walk(t.get(k))
for p in glob.glob("roles/shopfront/tasks/*.yml"):
    walk(yaml.safe_load(open(p)))
users = [t for t in tasks if "shopfront_api_key" in yaml.safe_dump(t) or "vault_shop_api_key" in yaml.safe_dump(t)]
if not users:
    sys.exit("FAIL: no task of the role shopfront uses shopfront_api_key")
if not all(t.get("no_log") is True for t in users):
    sys.exit("FAIL: every task that uses shopfront_api_key needs no_log: true")
PY
    ok=0
    for h in app1 app2; do
      [[ $(docker exec "$h" stat -c '%a %U' /etc/shop 2>/dev/null) == "750 root" ]] || { echo "FAIL: $h: /etc/shop must be a folder owned by root, mode 0750"; ok=1; }
      [[ $(docker exec "$h" stat -c '%a %U' /etc/shop/app.env 2>/dev/null) == "600 root" ]] || { echo "FAIL: $h: /etc/shop/app.env must exist, owned by root, mode 0600"; ok=1; }
      docker exec "$h" grep -qxF "SHOP_API_KEY=$secret" /etc/shop/app.env 2>/dev/null || { echo "FAIL: $h: app.env must contain the line SHOP_API_KEY=<your key>"; ok=1; }
    done
    docker exec lb1 test -e /etc/shop/app.env && { echo "FAIL: lb1 must not receive the API key"; ok=1; }
    [[ $ok == 0 ]] && echo "OK: the key is encrypted in Git and delivered only to the shop servers"
    exit $ok
    ;;
  answers)
    bash scripts/check-answers.sh
    ;;
  *)
    echo "usage: $0 yaml|inventory|common|structure|first-run|app|lb|idempotent|drift|vault|answers"; exit 2
    ;;
esac
