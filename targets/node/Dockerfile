# A minimal "server" for Ansible to manage: Ubuntu 24.04 with SSH, Python and nginx.
# Used by targets/up.sh (your Codespace) and by the autograder (GitHub Actions).
# nginx is preinstalled to save time; nothing is configured or started.
# Its default site listens on IPv4 only, so it starts on hosts without IPv6.
FROM ubuntu:24.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openssh-server python3 sudo ca-certificates curl nginx \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i '/listen \[::\]/d' /etc/nginx/sites-available/default \
 && mkdir -p /run/sshd \
 && useradd --create-home --shell /bin/bash azureuser \
 && echo "azureuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/azureuser \
 && chmod 0440 /etc/sudoers.d/azureuser \
 && mkdir -p /home/azureuser/.ssh \
 && chmod 700 /home/azureuser/.ssh

# The public key is passed at build time so each student uses their own key.
ARG PUBKEY
RUN echo "$PUBKEY" > /home/azureuser/.ssh/authorized_keys \
 && chmod 600 /home/azureuser/.ssh/authorized_keys \
 && chown -R azureuser:azureuser /home/azureuser/.ssh

EXPOSE 22 80 8080
CMD ["/usr/sbin/sshd", "-D", "-e"]
