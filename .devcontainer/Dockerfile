FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

USER root
RUN for source in /etc/apt/sources.list.d/*; do \
      if [ -f "$source" ] && grep -q 'dl.yarnpkg.com' "$source"; then \
        rm "$source"; \
      fi; \
    done
USER vscode
