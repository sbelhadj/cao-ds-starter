# DS answers

Answer every line marked `ANSWER:` on the same line, right after `ANSWER:`, in one to four sentences. For pasted output (Q6), write a short summary on the `ANSWER:` line and paste the output below it.

Name: ANSWER:

1. `legacy/bootstrap.sh` fails, or does damage, if it runs twice on the same server. Name two of its lines that cause this, and say which module replaced each one in your `common` role.
   ANSWER:

2. Which of your six fixes in `data/catalog.yml` would have produced a wrong page without any error message? Give two and what the page would have shown.
   ANSWER:

3. Where does each of app1 and app2 get its `shopfront_color`? What would `-e shopfront_color=red` change, and why?
   ANSWER:

4. Why do `shopfront_port` and `loadbalancer_backend_port` both come from `shop_backend_port` in `group_vars/all`, instead of the `loadbalancer` role reading `shopfront_port` directly?
   ANSWER:

5. Someone edits `/etc/nginx/sites-available/default` by hand on app1 only. What does your next `make run` report, which handler runs, and on which hosts?
   ANSWER:

6. Paste the PLAY RECAP of a second run of `make run`.
   ANSWER:

7. Why is `vault.yml` in `group_vars/app/` and not in `group_vars/all/`? Where is the vault password, and why is it not in the repository?
   ANSWER:
