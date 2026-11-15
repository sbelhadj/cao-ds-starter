# roles

- `common/` is given (Part B): fix it, do not recreate it.
- `shopfront/` and `loadbalancer/` are yours to create (Parts C and D):

```
cd roles
ansible-galaxy role init shopfront
ansible-galaxy role init loadbalancer
cd ..
```

Then, in each new role:

1. replace `meta/main.yml` with `reference/meta-main.yml`, and change
   `role_name` and `description`;
2. copy the templates you need from `reference/` into `templates/`
   (and `reference/maintenance.html` into `shopfront/files/`);
3. delete what you do not use (`tests/`, `vars/`, `README.md`, empty `files/`):
   ansible-lint checks every file left.

Every variable a role defines (in `defaults/`, with `register:` or `set_fact`)
starts with the role name: `shopfront_...`, `loadbalancer_...`, `common_...`.
