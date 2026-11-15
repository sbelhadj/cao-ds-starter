# DS · SESAME Shop goes live

Cloud Automation and Orchestration (I5_946) · ING5 · Practical DS on weeks 1 to 4: Infrastructure as Code and Ansible.

| | |
| --- | --- |
| Duration | 2 hours, in the room |
| Work | individual |
| Assignment in Classroom 50 | `ds`, repository `SESAME-U/ing5-cic-s1-cao-ds-<username>` |
| Grading | 20 points, autograded on every push; the last push before the end of the DS counts |

## Rules

- **Allowed:** the course slides, the lab and workshop handouts, your own lab repositories (lab0 to lab2, ws1), the official Ansible documentation (docs.ansible.com).
- **Not allowed:** any AI assistant (Copilot, ChatGPT, Claude, Gemini...), messaging, sharing files or code. Copilot and chat are turned off in this Codespace: do not turn them back on.
- Your Git history is part of the evidence. **Commit and push at least every 30 minutes**: a push that arrives after the end of the DS does not count.
- The instructor may ask you to explain any line you submitted. A line you cannot explain earns no points.
- Do not edit `tests/`, `targets/`, `reference/`, `legacy/`, `.github/`, `Makefile` or `ansible.cfg` (except the one line of Part E). Changing them counts as tampering.

## The problem

SESAME Shop opens its online store on Monday. The platform has three servers:

```
                     your browser
                          |
                 http://localhost:8080
                          |
                  +---------------+
                  |      lb1      |   group lb: nginx load balancer,
                  |  nginx :80    |   the only public entry point
                  +---------------+
                     /         \
            app1:8080           app2:8080      private network cao-ds-net
                   /             \
        +---------------+   +---------------+
        |     app1      |   |     app2      |  group app: the shop front,
        |  nginx :8080  |   |  nginx :8080  |  a page built from the catalog
        +---------------+   +---------------+
```

The colleague who started the automation left the company. You inherit:

- `data/catalog.yml`, written by the marketing team, which is broken;
- `roles/common/`, translated in a hurry from the old manual script `legacy/bootstrap.sh`, which does not work;
- an empty inventory and an empty playbook.

**Your job:** finish the automation, so that `make run` builds the whole shop from three blank servers, and a second `make run` changes nothing.

Everything you need was seen in weeks 1 to 4. Do the parts in order: each one needs the previous one.

| Part | What you do | Weeks | Suggested time |
| --- | --- | --- | --- |
| Start | Accept, Codespace, three servers | | 10 min |
| A | Inventory, then fix the catalog YAML | 2 | 15 min |
| B | Fix the role `common` | 1, 2, 3 | 20 min |
| C | Write the role `shopfront` | 3, 4 | 35 min |
| D | Write the role `loadbalancer` | 4 | 15 min |
| E | Put the API key in Ansible Vault | 3 | 10 min |
| End | Lint, test, answers, push | | 15 min |

## Start (10 min)

1. Open the `ds` assignment link, click **Accept assignment**, then **Open repository**.
2. **Code**, **Codespaces**, **Create codespace on main**. Wait for `Toolbox ready` (about 2 minutes), then run `make check`. The last line must read `Environment ready.`
3. Start the three servers:

   ```
   make up
   ```

   It prints one line per server and writes `inventory/generated.ini`. `make up` always gives you three **blank** servers: use it again whenever you want to start from zero.

Run every command from the repository root, so that Ansible reads the repository's `ansible.cfg`. `make help` lists every command.

## Part A: inventory and YAML (15 min, 3 points)

### A1. The inventory

In `inventory/hosts.ini`, below the comments:

- group `app` with app1 and app2, group `lb` with lb1;
- a parent group `shop` whose children are `app` and `lb`;
- copy each line of `inventory/generated.ini` **whole**: `internal_address` is used in Part D.

No variables in `hosts.ini`: they go in `group_vars/` and `host_vars/`.

```
ansible-inventory --graph
make ping
```

`make ping` must show `SUCCESS` and `pong` for lb1, app1 and app2.

### A2. The catalog

`data/catalog.yml` either does not load, or loads with wrong values. There are six problems. Fix **how** each value is written so that the file loads with exactly these values and types. Do not change the values, do not add or remove keys.

| Key | Type | Value |
| --- | --- | --- |
| `shop_name` | text | `SESAME Shop` |
| `tagline` | text | `Shop smart: pay less` |
| `api_version` | text | `1.10` |
| `closing_time` | text | `22:30` |
| `ship_to` | list of four texts | `TN`, `DZ`, `NO`, `FR` |
| `products` | list of four maps | as in the file, with: |
| `name` | text | as written in the file, in full |
| `sku` | text, six digits | as written in the file, leading zeros included |
| `price` | number | as written |
| `stock` | whole number | as written |

```
make test-yaml
```

It prints `OK` when every value and type is right.

## Part B: fix the role `common` (20 min, 3 points)

The role `common` must bring **every** server (lb1, app1, app2) to this state:

| Item | Expected |
| --- | --- |
| Packages | `nginx`, `tree`, `jq` installed (list `common_packages`) |
| Users | `deploy` with shell `/bin/bash`, `monitor` with shell `/usr/sbin/nologin`, each with a home folder (list `common_users`) |
| `/etc/motd` | exactly the line in `common_motd` |
| `/opt/shop` | a folder owned by `deploy`, mode `0755` |
| nginx | running and enabled |
| `/etc/nginx/conf.d/00-security.conf` | from the template `security.conf.j2`; when it changes, nginx is **reloaded** so that it hides its version |
| Kernel version | read and displayed, as today |

`legacy/bootstrap.sh` shows what the operators used to do by hand. The role does the same, but today it does not even load, its second run fails, and `ansible-lint` does not accept it.

Fix the role so that:

- it uses Ansible modules, not `shell` or `command`, for everything that changes the server; a `command` that only reads is allowed if it never reports `changed`;
- a second run reports `changed=0` and fails nothing;
- every variable the role registers starts with `common_`;
- `make lint` finds nothing in it.

Keep the role name, its variable names and its handler. Read each error message to the end: it gives the file and the line.

Then write the **first play** of `playbooks/site.yml`: `hosts: shop`, `become: true`, the role `common`. Run it twice:

```
make run
make run
make test-common
```

## Part C: the role `shopfront` (35 min)

```
cd roles && ansible-galaxy role init shopfront && cd ..
```

Then follow `roles/README.md`: replace `meta/main.yml` with `reference/meta-main.yml` and fill it in, delete what you do not use.

### The contract

The autograder relies on these names and paths. Everything else (task names, file names, how you split tasks) is your choice.

| Item | Must be |
| --- | --- |
| Role defaults | `shopfront_port: 80`, `shopfront_root: /var/www/shop`, `shopfront_color` (any colour) |
| `group_vars/all/vars.yml` | `shop_maintenance: false`; `shop_backend_port: 8080`; `shopfront_port` taken from `shop_backend_port` |
| `group_vars/app/vars.yml` | `shopfront_color`, different from the role default |
| `host_vars/app2.yml` | `shopfront_color`, different from the group value. app1 gets no `host_vars` file: it keeps the group value |
| nginx site | `/etc/nginx/sites-available/default`, written from a template (start from `reference/nginx-shopfront.conf.j2`); it listens on `shopfront_port`, serves `shopfront_root`, and **notifies a handler of the role** that reloads nginx |
| Shop page | `<shopfront_root>/index.html`, written from a template (start from `reference/index.html.j2`: replace every `TODO-n`, keep the HTML around them exactly) |
| Health page | `<shopfront_root>/health`, content exactly `OK <inventory name of the host>` |
| Maintenance page | when `shop_maintenance` is true, `reference/maintenance.html` is published as `<shopfront_root>/maintenance.html`; when it is false, that file must not exist. The switch can be given on the command line (`-e shop_maintenance=true`): it must work both ways |
| nginx | running and enabled, without depending on another role |
| Play 2 of `site.yml` | `hosts: app`, `become: true`, `vars_files: ../data/catalog.yml`, the role `shopfront` |

The page shows, among other things, one line per product in this exact form:

```
<li>Laptop ThinkPad E14 | 004517 | 2499.000 TND | in stock</li>
<li>Headset Jabra Evolve2 | 310007 | 349.900 TND | sold out</li>
```

Price with three decimals; `in stock` when `stock` is above 0, otherwise `sold out`.

### Check

```
make run
curl localhost:8081
curl localhost:8082
curl localhost:8081/health
make test-inventory
```

app1 and app2 show their own colour, `Served by app1` or `Served by app2`, `Running Ubuntu 24.04` and the four products. You can also open ports 8081 and 8082 from the **Ports** tab.

## Part D: the role `loadbalancer` (15 min)

Create the role as in Part C.

| Item | Must be |
| --- | --- |
| Role defaults | `loadbalancer_backend_port: 80` |
| `group_vars/all/vars.yml` | `loadbalancer_backend_port` taken from `shop_backend_port` |
| nginx site | `/etc/nginx/sites-available/default` on lb1, from a template (start from `reference/nginx-loadbalancer.conf.j2`) that **notifies a handler of the role** that reloads nginx |
| Server list | one `server <internal_address>:<port>;` line per host of the group `app`, built with a loop over `groups[...]` and `hostvars[...]`. No host name or address typed by hand |
| nginx | running and enabled |
| Play 3 of `site.yml` | `hosts: lb`, `become: true`, the role `loadbalancer` |

The two roles must not read each other's variables: `group_vars/all` wires them together.

```
make run
for i in 1 2 3 4; do curl -s localhost:8080 | grep "Served by"; done
```

The answers alternate between app1 and app2.

## Part E: the API key in Ansible Vault (10 min, 2 points)

The shop servers need an API key. It must be encrypted in Git, delivered only to app1 and app2, and never printed.

1. `make vault-pass` writes the **DS vault password** `sesame-cao-ds` to `~/.cao_ds_vault_pass`. Everyone uses it, because the autograder must decrypt your file: a shortcut for the exam, never a practice to copy. In `ansible.cfg`, remove the `#` in front of `vault_password_file`.
2. Create the encrypted file:

   ```
   export EDITOR=nano
   ansible-vault create inventory/group_vars/app/vault.yml
   ```

   with one line: `vault_shop_api_key: <your own key>`, at least 16 characters, letters, digits, `-` and `_` only.
3. In `inventory/group_vars/app/vars.yml`, add exactly:

   ```yaml
   shopfront_api_key: "{{ vault_shop_api_key }}"
   ```

4. In the role `shopfront`: a folder `/etc/shop` (owner root, mode `0750`), and a file `/etc/shop/app.env` (owner root, mode `0600`) containing the line `SHOP_API_KEY=<the key>`. Every task that uses the key has `no_log: true`.

Your key must appear in clear text nowhere in the repository. Check that `ansible-vault view inventory/group_vars/app/vault.yml` works: **a vault file encrypted with another password makes every run fail**, on your Codespace and on the autograder.

## End (15 min)

1. `make lint`: no finding. Do not hide findings with `# noqa` or a skip list.
2. `make run` twice: the second PLAY RECAP shows `changed=0` on lb1, app1 and app2.
3. `make test` runs every autograder check on fresh servers (about 4 minutes). Run it at least once before the end. It replaces your three servers with the test ones, configured by your playbook: you can keep working on them.
4. Fill in every `ANSWER:` line of `ANSWERS.md`, on the same line.
5. Push:

   ```
   git add -A
   git commit -m "DS"
   git push
   ```

   On GitHub, open **Actions** and the latest **Autograding** run to see your score.
6. `make down`, then stop your Codespace.

## Grading (20 points)

| Check | Part | Points |
| --- | --- | --- |
| `data/catalog.yml` loads with the expected values and types | A2 | 2 |
| Groups `app`, `lb`, `shop` in `hosts.ini`; `shopfront_color` in `group_vars/app` and `host_vars/app2.yml` only | A1, C | 1 |
| The role `common` alone converges on three blank servers; its second run changes nothing | B | 3 |
| Three roles and three plays in the expected shape; `ansible-lint` (moderate profile) finds nothing | B, C, D | 2 |
| app1 and app2 serve the right page on port 8080, `/health` answers, no maintenance page | C | 3 |
| lb1 balances over app1 and app2, from a server list built from the inventory | D | 2 |
| Second run of `site.yml`: `changed=0` on every server | all | 2 |
| Hand edits of the nginx sites are reverted and trigger the handlers; maintenance works on and off | C, D | 2 |
| API key encrypted, in no other file in clear, delivered with mode 0600 to app1 and app2 only, `no_log` | E | 2 |
| `ANSWERS.md` complete | all | 1 |

How the autograder works:

- On every push, GitHub Actions starts three **blank** servers and runs your playbook against them. It never uses your Codespace's servers.
- The checks are independent where possible. A catalog value that is wrong costs points only in the catalog check. If the role `common` fails, the plays of Parts C and D are still run on their own and graded.
- The instructor reads `ANSWERS.md` and can adjust its point if an answer is empty in substance.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `YAML parsing failed ... missing quotes around a template block` | a value starts with `{{` without quotes | `path: "{{ common_app_dir }}"` |
| `mapping values are not allowed here` | a `: ` inside an unquoted text | quote the whole value |
| `The requested handler ... was not found` | the name in `notify` and the handler's name differ | same name, character for character |
| `useradd: user 'deploy' already exists` | a `command` that is not idempotent | use the right module |
| `changed=1` on a second run | a `shell`/`command` task, or a task without its "absent" twin | find the yellow task in the second run |
| `Conditionals must have a boolean result` | a `when` on a value given with `-e`, without `\| bool` | `when: shop_maintenance \| bool` |
| `'products' is undefined` | play 2 does not load the catalog | `vars_files: ../data/catalog.yml` in play 2 |
| `curl localhost:8081` gives nothing | nginx still on port 80: the site template did not change, or the handler did not run | check `shopfront_port` with `ansible app1 -m ansible.builtin.debug -a var=shopfront_port` |
| lb1 answers `502 Bad Gateway` | wrong address or port in the server list | read the generated file: `docker exec lb1 cat /etc/nginx/sites-available/default` |
| `Decryption failed` | `vault.yml` encrypted with another password | `ansible-vault rekey --ask-vault-pass --new-vault-password-file ~/.cao_ds_vault_pass inventory/group_vars/app/vault.yml` |
| `The vault password file ... was not found` | `vault_password_file` uncommented before `make vault-pass` | `make vault-pass` |
| `git push` rejected | the remote has a commit you do not have | `git pull --rebase`, then `git push` |

Still stuck: rerun the command with `-vvv` and read the lines just before the error. You can raise your hand for a problem with the environment, not with your code.
